#!/usr/bin/env bash
# scripts/scan-db.sh
# Camada 06 · Banco de Dados & PII
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

scan_header "06" "Banco de Dados & PII"
LAYER="06-database"

# 1. SQL com concatenação de string (clássico SQLi)
SQLI=$(grep -rEnH --include="*.{js,ts,py,go,rb,php,java}" \
  --exclude-dir={node_modules,.git,vendor,dist,build,__pycache__,target} \
  -E "(SELECT|INSERT|UPDATE|DELETE|WHERE)\s+.*['\"].*\+\s*[a-zA-Z_]" . 2>/dev/null | head -10 || true)
if [ -n "$SQLI" ]; then
  echo "$SQLI" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "needs-review" "Possível SQL com concatenação de string" \
      "$file" "$line" "db:sql-string-concat" \
      "Use prepared statements ou ORM com binding posicional" \
      "Camada 6 · Banco de Dados — guia pág. 14"
  done
fi

# 2. Conexão sem TLS
DB_NO_TLS=$(grep -rEnH --include="*.{js,ts,py,yaml,yml,toml,env}" \
  --exclude-dir={node_modules,.git,vendor,dist,build,__pycache__,target} \
  -E "(postgres|mysql|mongodb)://[^?\"' ]*\"" . 2>/dev/null | grep -v "ssl=true\|sslmode=require\|tls=true" | head -5 || true)
if [ -n "$DB_NO_TLS" ]; then
  echo "$DB_NO_TLS" | while IFS=: read -r file line _; do
    # Pula localhost e exemplos
    NEARBY=$(sed -n "${line}p" "$file" 2>/dev/null)
    if echo "$NEARBY" | grep -qiE "localhost|127\.0\.0\.1|example|test"; then continue; fi
    add_finding "$LAYER" "needs-review" "Connection string sem TLS aparente" \
      "$file" "$line" "db:no-tls" \
      "Adicione ?sslmode=require (Postgres) ou ssl=true conforme o driver" \
      "Camada 6 · Banco de Dados"
  done
fi

# 3. Credenciais default
DEFAULT_CREDS=$(grep -rEnH --include="*.{js,ts,py,yaml,yml,toml,env,sh,Dockerfile*}" \
  --exclude-dir={node_modules,.git,dist,build,__pycache__} \
  -E "(postgres:postgres|root:root|admin:admin|mongo:mongo|user:password)" \
  . 2>/dev/null | head -5 || true)
if [ -n "$DEFAULT_CREDS" ]; then
  echo "$DEFAULT_CREDS" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "high" "Credenciais default detectadas (postgres:postgres etc)" \
      "$file" "$line" "db:default-creds" \
      "Substitua por credenciais únicas via env var" \
      "Camada 6 · Banco de Dados — guia pág. 14"
  done
fi

# 4. Detectar PII em schema
SCHEMA_FILES=$(find . \( -name "schema.sql" -o -name "*.sql" -o -name "schema.prisma" -o -name "models.py" \) \
  -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null | head -10)
PII_COLS=""
for s in $SCHEMA_FILES; do
  HITS=$(grep -inE "\b(cpf|cnpj|rg|passport|ssn|credit_card|card_number|cvv)\b" "$s" 2>/dev/null | head -10 || true)
  if [ -n "$HITS" ]; then
    echo "$HITS" | while IFS=: read -r line content; do
      add_finding "$LAYER" "needs-review" "Coluna PII detectada — verifique encryption at rest e column-level encryption" \
        "$s" "$line" "db:pii-column" \
        "Use pgcrypto, AWS KMS column encryption ou tokenização para CPF, cartão, etc." \
        "Camada 6 · Banco de Dados — guia pág. 15"
    done
  fi
done

# 5. ORM sem RLS (Prisma multitenant heuristic)
if [ -f prisma/schema.prisma ]; then
  if grep -q "tenantId\|tenant_id\|workspaceId\|orgId" prisma/schema.prisma 2>/dev/null; then
    add_finding "$LAYER" "needs-review" "Schema multitenant detectado — confirme RLS ou middleware de tenant scope" \
      "prisma/schema.prisma" "" "db:multitenant-no-rls" \
      "Implemente RLS no Postgres + middleware no Prisma que sete app.tenant_id" \
      "Camada 6 · Banco de Dados — guia pág. 15"
  fi
fi

# 6. Backup configurado?
HAS_BACKUP_CFG=false
for f in backup.sh wal-g.yaml pg_dump_*.sh restic.json restic-config.yaml; do
  [ -f "$f" ] && HAS_BACKUP_CFG=true
done
if ! $HAS_BACKUP_CFG; then
  add_finding "$LAYER" "low" "Nenhuma config de backup detectada no repo" \
    "" "" "db:no-backup-config" \
    "Documente estratégia de backup (RPO, RTO, cross-region) em runbook" \
    "Camada 6 · Banco de Dados"
fi

log_ok "Camada 06 concluída"

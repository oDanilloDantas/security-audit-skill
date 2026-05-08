#!/usr/bin/env bash
# scripts/scan-auth.sh
# Camada 05 · Auth & AuthZ
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

scan_header "05" "Auth & AuthZ"
LAYER="05-auth"

# 1. JWT secret hardcoded ou fraco
JWT_SECRETS=$(grep -rEnH --include="*.{js,ts,py,go,java}" \
  --exclude-dir={node_modules,.git,vendor,dist,build,__pycache__,target} \
  "jwt[._-]?secret\s*[:=]\s*['\"][^'\"]{1,16}['\"]" . 2>/dev/null | head -5 || true)
if [ -n "$JWT_SECRETS" ]; then
  echo "$JWT_SECRETS" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "critical" "JWT secret curto/hardcoded (provável)" \
      "$file" "$line" "auth:jwt-weak-secret" \
      "Use 256+ bits gerado com CSPRNG, vindo de env var validada no boot" \
      "Camada 5 · Auth & AuthZ — guia pág. 12"
  done
fi

# 2. JWT verify sem alg explícito
JWT_VERIFY=$(grep -rEnH --include="*.{js,ts}" \
  --exclude-dir={node_modules,.git,dist,build} \
  "jwt\.verify\s*\(" . 2>/dev/null | head -10 || true)
if [ -n "$JWT_VERIFY" ]; then
  echo "$JWT_VERIFY" | while IFS=: read -r file line content; do
    # Verifica se há "algorithms:" na mesma linha ou nas próximas 5 linhas
    NEARBY=$(awk -v ln="$line" 'NR >= ln && NR <= ln+5' "$file" 2>/dev/null)
    if ! echo "$NEARBY" | grep -q "algorithms"; then
      add_finding "$LAYER" "high" "jwt.verify sem algorithms explícito" \
        "$file" "$line" "auth:jwt-no-alg" \
        "Especifique algorithms: ['RS256'] ou similar pra evitar alg: none" \
        "Camada 5 · Auth & AuthZ — guia pág. 13"
    fi
  done
fi

# 3. bcrypt cost baixo
BCRYPT_COST=$(grep -rEnH --include="*.{js,ts,py}" \
  --exclude-dir={node_modules,.git,dist,build,__pycache__} \
  "bcrypt\.(hash|hashSync|gensalt|compare).*[,\(]\s*([1-9])\s*[,\)]" . 2>/dev/null | head -5 || true)
if [ -n "$BCRYPT_COST" ]; then
  echo "$BCRYPT_COST" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "medium" "Bcrypt com cost < 10 (pode ser inseguro em 2026+)" \
      "$file" "$line" "auth:bcrypt-low-cost" \
      "Use cost ≥ 12 em produção" "Camada 5 · Auth & AuthZ"
  done
fi

# 4. Senha em texto plano (heurística)
PLAINTEXT_PASS=$(grep -rEnH --include="*.{js,ts,py,go}" \
  --exclude-dir={node_modules,.git,dist,build,__pycache__,target} \
  "(user\.|users\.)?password\s*=\s*req\.(body|query)" . 2>/dev/null | head -5 || true)
if [ -n "$PLAINTEXT_PASS" ]; then
  echo "$PLAINTEXT_PASS" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "needs-review" "Possível atribuição de senha em texto plano" \
      "$file" "$line" "auth:plaintext-password" \
      "Hashe a senha com bcrypt/argon2 antes de armazenar" \
      "Camada 5 · Auth & AuthZ"
  done
fi

# 5. Express sem session secret seguro
if grep -q '"express-session"' package.json 2>/dev/null; then
  SESS_BAD=$(grep -rEnH --include="*.{js,ts}" \
    --exclude-dir={node_modules,dist,build} \
    "session\(\s*\{[^}]*secret\s*:\s*['\"][^'\"]{1,16}['\"]" . 2>/dev/null | head -3 || true)
  if [ -n "$SESS_BAD" ]; then
    echo "$SESS_BAD" | while IFS=: read -r file line _; do
      add_finding "$LAYER" "high" "Session secret muito curto/hardcoded" \
        "$file" "$line" "auth:session-weak" \
        "Use 256+ bits via env var" "Camada 5 · Auth & AuthZ"
    done
  fi
fi

# 6. OAuth redirect_uri com wildcard
OAUTH_WILDCARD=$(grep -rEnH --include="*.{js,ts,py,yaml,yml,json}" \
  --exclude-dir={node_modules,.git,dist,build,__pycache__} \
  "redirect[_-]?uri.*\*" . 2>/dev/null | head -3 || true)
if [ -n "$OAUTH_WILDCARD" ]; then
  echo "$OAUTH_WILDCARD" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "high" "OAuth redirect_uri com wildcard" \
      "$file" "$line" "auth:oauth-wildcard" \
      "Use allowlist exata; sem * em redirect_uri" "Camada 5 · Auth & AuthZ"
  done
fi

log_ok "Camada 05 concluída"

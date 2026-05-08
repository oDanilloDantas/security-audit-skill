#!/usr/bin/env bash
# scripts/scan-secrets.sh
# Camada 01 · Secrets & Credenciais
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

scan_header "01" "Secrets & Credenciais"
LAYER="01-secrets"

# 1. .env no .gitignore
if [ -f .gitignore ]; then
  if grep -qE "^\.env$|^\.env\.local$|^\.env\..*" .gitignore; then
    log_ok ".env está no .gitignore"
  else
    add_finding "$LAYER" "high" ".env não está no .gitignore" \
      ".gitignore" "" "secrets:env-not-ignored" \
      "Adicione .env e .env.local ao .gitignore" \
      "Camada 1 · Secrets — guia pág. 4"
    log_warn ".env não listado no .gitignore"
  fi
else
  add_finding "$LAYER" "medium" ".gitignore não encontrado" \
    "" "" "secrets:no-gitignore" \
    "Crie .gitignore na raiz do projeto" \
    "Camada 1 · Secrets — guia pág. 4"
fi

# 2. Verifica se .env foi commitado em algum momento
if git rev-parse --git-dir >/dev/null 2>&1; then
  if git log --all --full-history --source -- .env 2>/dev/null | grep -q commit; then
    add_finding "$LAYER" "critical" ".env já foi commitado em algum momento" \
      ".env" "" "secrets:env-in-history" \
      "Use git filter-repo para remover o arquivo do histórico e rotacione todos os secrets imediatamente" \
      "Camada 1 · Secrets — guia pág. 4"
    log_err ".env aparece no histórico do Git"
  else
    log_ok ".env nunca commitado"
  fi
fi

# 3. Gitleaks no histórico inteiro
if need_cmd gitleaks "rode ./scripts/setup.sh"; then
  log_info "Rodando gitleaks no histórico..."
  TMP=$(mktemp)
  gitleaks detect --source . --report-path "$TMP" --report-format json --no-banner 2>/dev/null || true

  if [ -s "$TMP" ]; then
    # Parse e adiciona findings via Python (cap em 50)
    python3 - "$TMP" "$LAYER" "$FINDINGS_DIR" <<'PY' || true
import json, sys, os
tmp_path, layer, findings_dir = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(tmp_path))
except Exception:
    sys.exit(0)
out_file = os.path.join(findings_dir, f"{layer}.jsonl")
count = 0
with open(out_file, "a") as out:
    for f in data[:50]:
        rule = f.get("RuleID", "unknown")
        desc = f.get("Description", rule)
        finding = {
            "layer": layer,
            "severity": "critical",
            "title": desc,
            "file": f.get("File", ""),
            "line": str(f.get("StartLine", "")),
            "rule": f"gitleaks:{rule}",
            "fix": "Remova o secret do código, rotacione a credencial vazada, e limpe o histórico com git filter-repo",
            "doc_ref": "Camada 1 · Secrets — guia pág. 4-5"
        }
        out.write(json.dumps(finding) + "\n")
        count += 1
print(f"COUNT={count}")
PY
    log_err "Gitleaks completou — verifique findings em $FINDINGS_DIR/$LAYER.jsonl"
  else
    log_ok "Nenhum secret detectado pelo gitleaks"
  fi
  rm -f "$TMP"
fi

# 4. AWS access keys no histórico (regex direto)
if git rev-parse --git-dir >/dev/null 2>&1; then
  AWS_HITS=$(git log --all -p 2>/dev/null | grep -cE "AKIA[0-9A-Z]{16}" || true)
  if [ "${AWS_HITS:-0}" -gt 0 ]; then
    add_finding "$LAYER" "critical" "$AWS_HITS ocorrências de AWS access key no histórico" \
      "" "" "secrets:aws-key-history" \
      "Rotacione as keys no IAM e limpe o histórico do Git com filter-repo" \
      "Camada 1 · Secrets — guia pág. 5"
    log_err "$AWS_HITS AWS access keys no histórico"
  fi
fi

# 5. Hardcoded em arquivos comuns de config
log_info "Verificando configs hardcoded..."
PATTERNS='(api[_-]?key|secret[_-]?key|password|passwd|token|jwt[_-]?secret)\s*[=:]\s*["\x27][^"\x27]{8,}["\x27]'

# Excluir node_modules, .git, vendor, dist, build, etc.
HARDCODED=$(grep -rEnH --include="*.{js,ts,jsx,tsx,py,go,rb,java,php,yaml,yml,json,env,toml}" \
  --exclude-dir={node_modules,.git,vendor,dist,build,.next,coverage,target,__pycache__} \
  -i "$PATTERNS" . 2>/dev/null | head -30 || true)

if [ -n "$HARDCODED" ]; then
  echo "$HARDCODED" | while IFS=: read -r file line content; do
    # Filtra placeholders óbvios
    if echo "$content" | grep -qiE 'placeholder|example|your-|xxx|todo|fixme|test|sample|dummy'; then continue; fi
    if echo "$content" | grep -qiE 'process\.env|os\.environ|os\.getenv|getenv\(|System\.getenv'; then continue; fi
    add_finding "$LAYER" "needs-review" "Possível secret hardcoded" \
      "$file" "$line" "secrets:hardcoded-pattern" \
      "Mova para variável de ambiente; valide com schema no boot" \
      "Camada 1 · Secrets — guia pág. 4"
  done
fi

# 6. Logs com nível de risco — verifica se Pino/Winston redact está configurado
if [ -f package.json ]; then
  if grep -q '"pino"' package.json 2>/dev/null; then
    if ! grep -rE "redact\s*:" --include="*.js" --include="*.ts" \
         --exclude-dir={node_modules,dist,build} . >/dev/null 2>&1; then
      add_finding "$LAYER" "medium" "Pino instalado mas sem redact configurado" \
        "" "" "secrets:pino-no-redact" \
        "Configure redact paths no logger pra remover authorization, cookie, password, etc." \
        "Camada 1 · Secrets — guia pág. 5"
      log_warn "Pino sem redact configurado"
    else
      log_ok "Pino com redact configurado"
    fi
  fi
fi

log_ok "Camada 01 concluída"

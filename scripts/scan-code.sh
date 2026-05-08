#!/usr/bin/env bash
# scripts/scan-code.sh
# Camada 03 · Código & Lógica de Aplicação
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

scan_header "03" "Código & Lógica de Aplicação"
LAYER="03-code"

# 1. Semgrep — SAST principal
if need_cmd semgrep "rode ./scripts/setup.sh"; then
  log_info "Rodando Semgrep com regras OWASP..."
  semgrep --config=p/owasp-top-ten --config=p/security-audit \
    --json --quiet --error 2>/dev/null | \
    python3 - "$LAYER" "$FINDINGS_DIR" <<'PY' || true
import json, sys, os
layer, findings_dir = sys.argv[1], sys.argv[2]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sev_map = {"ERROR":"high", "WARNING":"medium", "INFO":"low"}
out_file = os.path.join(findings_dir, f"{layer}.jsonl")
results = data.get("results", [])
with open(out_file, "a") as out:
    for r in results[:100]:  # cap em 100
        sev = sev_map.get(r.get("extra", {}).get("severity", "INFO"), "low")
        out.write(json.dumps({
            "layer": layer, "severity": sev,
            "title": r.get("extra", {}).get("message", r.get("check_id", ""))[:200],
            "file": r.get("path", ""),
            "line": str(r.get("start", {}).get("line", "")),
            "rule": f"semgrep:{r.get('check_id', '')}",
            "fix": r.get("extra", {}).get("fix", "Veja regra Semgrep"),
            "doc_ref": "Camada 3 · Código — guia pág. 8-9"
        }) + "\n")
print(f"[{layer}] {len(results)} findings do Semgrep")
PY
  log_ok "Semgrep concluído"
fi

# 2. Bandit (Python)
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if need_cmd bandit "instale com pip install bandit"; then
    log_info "Rodando Bandit..."
    bandit -r . -ll -f json 2>/dev/null | \
      python3 - "$LAYER" "$FINDINGS_DIR" <<'PY' || true
import json, sys, os
layer, findings_dir = sys.argv[1], sys.argv[2]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sev_map = {"HIGH":"high", "MEDIUM":"medium", "LOW":"low"}
out_file = os.path.join(findings_dir, f"{layer}.jsonl")
with open(out_file, "a") as out:
    for r in data.get("results", [])[:50]:
        sev = sev_map.get(r.get("issue_severity", "LOW"), "low")
        out.write(json.dumps({
            "layer": layer, "severity": sev,
            "title": r.get("issue_text", ""),
            "file": r.get("filename", ""),
            "line": str(r.get("line_number", "")),
            "rule": f"bandit:{r.get('test_id', '')}",
            "fix": r.get("issue_cwe", {}).get("link", "Veja CWE"),
            "doc_ref": "Camada 3 · Código"
        }) + "\n")
PY
  fi
fi

# 3. gosec (Go)
if [ -f go.mod ]; then
  if need_cmd gosec "instale com 'go install github.com/securego/gosec/v2/cmd/gosec@latest'"; then
    log_info "Rodando gosec..."
    gosec -fmt=json -quiet ./... 2>/dev/null | \
      python3 - "$LAYER" "$FINDINGS_DIR" <<'PY' || true
import json, sys, os
layer, findings_dir = sys.argv[1], sys.argv[2]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sev_map = {"HIGH":"high", "MEDIUM":"medium", "LOW":"low"}
out_file = os.path.join(findings_dir, f"{layer}.jsonl")
with open(out_file, "a") as out:
    for r in data.get("Issues", [])[:50]:
        sev = sev_map.get(r.get("severity", "LOW"), "low")
        out.write(json.dumps({
            "layer": layer, "severity": sev,
            "title": r.get("details", "")[:200],
            "file": r.get("file", ""),
            "line": r.get("line", ""),
            "rule": f"gosec:{r.get('rule_id', '')}",
            "fix": "Veja regra gosec",
            "doc_ref": "Camada 3 · Código"
        }) + "\n")
PY
  fi
fi

# 4. Heurísticas básicas — busca por padrões problemáticos
log_info "Verificações heurísticas..."

# MD5/SHA1 em código
HASH_MATCHES=$(grep -rEnH --include="*.{js,ts,jsx,tsx,py,go,rb,java}" \
  --exclude-dir={node_modules,.git,vendor,dist,build,__pycache__,target} \
  -i 'md5|sha1\(' . 2>/dev/null | grep -vi "test\|spec\|example\|comment\|//" | head -5 || true)
if [ -n "$HASH_MATCHES" ]; then
  echo "$HASH_MATCHES" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "needs-review" "Possível uso de MD5/SHA1 (frágil para senhas)" \
      "$file" "$line" "code:weak-hash" \
      "Use bcrypt, argon2id ou scrypt para senhas; SHA1/MD5 só pra checksums não-críticos" \
      "Camada 3 · Código — guia pág. 8"
  done
fi

# JWT alg none
JWT_MATCHES=$(grep -rEnH --include="*.{js,ts,jsx,tsx,py,go}" \
  --exclude-dir={node_modules,.git,dist,build} \
  'algorithm.*none|alg.*none' . 2>/dev/null | head -5 || true)
if [ -n "$JWT_MATCHES" ]; then
  echo "$JWT_MATCHES" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "critical" "Possível JWT com alg: none" \
      "$file" "$line" "code:jwt-none" \
      "Sempre especifique algorithms: ['RS256'] ou similar fixo na verificação" \
      "Camada 3 · Código — guia pág. 9"
  done
fi

# eval() em JS/Python
EVAL_MATCHES=$(grep -rEnH --include="*.{js,ts,py}" \
  --exclude-dir={node_modules,.git,dist,build,__pycache__} \
  '(^|[^a-zA-Z_])eval\s*\(' . 2>/dev/null | grep -v "test\|spec" | head -5 || true)
if [ -n "$EVAL_MATCHES" ]; then
  echo "$EVAL_MATCHES" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "high" "Uso de eval() detectado" \
      "$file" "$line" "code:eval" \
      "Substitua eval por parsing seguro ou whitelist de operações" \
      "Camada 3 · Código"
  done
fi

log_ok "Camada 03 concluída"

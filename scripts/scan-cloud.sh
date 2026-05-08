#!/usr/bin/env bash
# scripts/scan-cloud.sh
# Camada 07 · Cloud & Infraestrutura
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

scan_header "07" "Cloud & Infraestrutura"
LAYER="07-cloud"

# 1. Terraform / CloudFormation com Tfsec
TF_FILES=$(find . -name "*.tf" -not -path "*/.terraform/*" 2>/dev/null | head -1)
if [ -n "$TF_FILES" ]; then
  if need_cmd tfsec "instale com 'brew install tfsec' ou veja tfsec.dev"; then
    log_info "Rodando tfsec..."
    tfsec . --format json --soft-fail 2>/dev/null | \
      python3 - "$LAYER" "$FINDINGS_DIR" <<'PY' || true
import json, sys, os
layer, findings_dir = sys.argv[1], sys.argv[2]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
sev_map = {"CRITICAL":"critical", "HIGH":"high", "MEDIUM":"medium", "LOW":"low"}
out_file = os.path.join(findings_dir, f"{layer}.jsonl")
with open(out_file, "a") as out:
    for r in data.get("results", [])[:100]:
        sev = sev_map.get(r.get("severity", "LOW"), "low")
        out.write(json.dumps({
            "layer": layer, "severity": sev,
            "title": r.get("description", ""),
            "file": r.get("location", {}).get("filename", ""),
            "line": str(r.get("location", {}).get("start_line", "")),
            "rule": f"tfsec:{r.get('rule_id', '')}",
            "fix": r.get("resolution", ""),
            "doc_ref": "Camada 7 · Cloud — guia pág. 16-17"
        }) + "\n")
PY
  fi

  if need_cmd checkov "instale com 'pip install checkov'"; then
    log_info "Rodando Checkov..."
    checkov -d . --framework terraform -o json --quiet --soft-fail 2>/dev/null | \
      python3 - "$LAYER" "$FINDINGS_DIR" <<'PY' || true
import json, sys, os
layer, findings_dir = sys.argv[1], sys.argv[2]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
out_file = os.path.join(findings_dir, f"{layer}.jsonl")
with open(out_file, "a") as out:
    for r in data.get("results", {}).get("failed_checks", [])[:50]:
        sev = (r.get("severity") or "MEDIUM").lower()
        if sev == "moderate": sev = "medium"
        out.write(json.dumps({
            "layer": layer, "severity": sev,
            "title": r.get("check_name", ""),
            "file": r.get("file_path", ""),
            "line": str(r.get("file_line_range", [0])[0]),
            "rule": f"checkov:{r.get('check_id', '')}",
            "fix": r.get("guideline", "Veja docs Checkov"),
            "doc_ref": "Camada 7 · Cloud"
        }) + "\n")
PY
  fi
fi

# 2. Dockerfile sem USER non-root
if [ -f Dockerfile ]; then
  if ! grep -qE "^USER\s+(?!root|0)" Dockerfile 2>/dev/null; then
    if grep -qE "^USER\s+(root|0)" Dockerfile 2>/dev/null || ! grep -qE "^USER\s+" Dockerfile 2>/dev/null; then
      add_finding "$LAYER" "high" "Dockerfile rodando como root (sem USER non-root)" \
        "Dockerfile" "" "cloud:docker-root" \
        "Adicione 'USER nonroot' (distroless) ou 'USER 1000' antes do CMD" \
        "Camada 7 · Cloud — guia pág. 17"
      log_warn "Dockerfile sem USER non-root"
    fi
  fi

  # Imagem base com :latest
  if grep -qE "^FROM\s+[^@:]+:latest" Dockerfile 2>/dev/null; then
    add_finding "$LAYER" "medium" "Dockerfile usa imagem com tag :latest" \
      "Dockerfile" "" "cloud:docker-latest" \
      "Pin por versão específica ou digest @sha256:" \
      "Camada 7 · Cloud"
  fi

  # ADD em vez de COPY
  if grep -qE "^ADD\s+" Dockerfile 2>/dev/null; then
    add_finding "$LAYER" "low" "Dockerfile usa ADD (prefira COPY)" \
      "Dockerfile" "" "cloud:docker-add" \
      "Use COPY exceto quando precisa de URL/tar extract" \
      "Camada 7 · Cloud"
  fi
fi

# 3. K8s manifests
K8S_FILES=$(find . \( -name "*.yaml" -o -name "*.yml" \) -path "*/k8s/*" 2>/dev/null | head -20)
K8S_FILES="$K8S_FILES $(find . \( -name "deployment.yaml" -o -name "deployment.yml" \) -not -path "*/node_modules/*" 2>/dev/null)"
for f in $K8S_FILES; do
  [ -f "$f" ] || continue
  if grep -q "kind: Deployment\|kind: Pod\|kind: StatefulSet" "$f" 2>/dev/null; then
    grep -q "runAsNonRoot: true" "$f" 2>/dev/null || \
      add_finding "$LAYER" "medium" "K8s manifest sem runAsNonRoot: true" \
        "$f" "" "cloud:k8s-runasroot" \
        "Adicione securityContext.runAsNonRoot: true e runAsUser: 1000" \
        "Camada 7 · Cloud"

    grep -q "readOnlyRootFilesystem: true" "$f" 2>/dev/null || \
      add_finding "$LAYER" "low" "K8s manifest sem readOnlyRootFilesystem" \
        "$f" "" "cloud:k8s-rw-root" \
        "Adicione securityContext.readOnlyRootFilesystem: true onde possível" \
        "Camada 7 · Cloud"
  fi
done

# 4. AWS hard-coded em IaC (sinaliza credenciais que deveriam ser via assume role)
AWS_HARDCODED=$(grep -rEnH --include="*.{tf,yaml,yml}" \
  --exclude-dir={.terraform,node_modules,.git} \
  "aws_access_key_id\s*=\s*['\"]AKIA" . 2>/dev/null | head -3 || true)
if [ -n "$AWS_HARDCODED" ]; then
  echo "$AWS_HARDCODED" | while IFS=: read -r file line _; do
    add_finding "$LAYER" "critical" "AWS access key hardcoded em IaC" \
      "$file" "$line" "cloud:aws-key-iac" \
      "Use IAM role / OIDC; nunca hardcode access keys em IaC" \
      "Camada 7 · Cloud"
  done
fi

log_ok "Camada 07 concluída"

#!/usr/bin/env bash
# scripts/scan-deps.sh
# Camada 02 · Dependências & Supply Chain
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

scan_header "02" "Dependências & Supply Chain"
LAYER="02-dependencies"

KIND=$(detect_project_kind)

# 1. Node.js
if [ -f package.json ]; then
  # Lockfile presente?
  if [ ! -f package-lock.json ] && [ ! -f yarn.lock ] && [ ! -f pnpm-lock.yaml ]; then
    add_finding "$LAYER" "high" "Lockfile ausente (package-lock.json/yarn.lock/pnpm-lock.yaml)" \
      "package.json" "" "deps:no-lockfile" \
      "Rode 'npm install' e commite o lockfile gerado" \
      "Camada 2 · Dependências — guia pág. 6"
    log_warn "Sem lockfile"
  else
    log_ok "Lockfile presente"
  fi

  # npm audit
  if need_cmd npm "instale Node.js"; then
    log_info "Rodando npm audit..."
    AUDIT_JSON=$(npm audit --json 2>/dev/null || true)
    if [ -n "$AUDIT_JSON" ]; then
      python3 - "$AUDIT_JSON" "$LAYER" "$FINDINGS_DIR" <<'PY' || true
import json, sys, os
audit_json, layer, findings_dir = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.loads(audit_json)
except Exception:
    sys.exit(0)
sev_map = {"critical":"critical", "high":"high", "moderate":"medium", "low":"low", "info":"info"}
out_file = os.path.join(findings_dir, f"{layer}.jsonl")
vulns = data.get("vulnerabilities", {})
with open(out_file, "a") as out:
    for name, v in vulns.items():
        sev = sev_map.get(v.get("severity", "info"), "info")
        via = v.get("via", [])
        title = via[0] if isinstance(via[0], str) else via[0].get("title", name) if via else name
        out.write(json.dumps({
            "layer": layer, "severity": sev,
            "title": f"{name}: {title}",
            "file": "package.json", "line": "",
            "rule": f"npm-audit:{name}",
            "fix": "Rode npm audit fix; se necessário, atualize manualmente",
            "doc_ref": "Camada 2 · Dependências — guia pág. 6-7"
        }) + "\n")
PY
      log_info "npm audit concluído (veja findings)"
    fi
  fi
fi

# 2. Python
if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
  if need_cmd pip-audit "instale com pip install pip-audit"; then
    log_info "Rodando pip-audit..."
    pip-audit --format=json 2>/dev/null | python3 - "$LAYER" "$FINDINGS_DIR" <<'PY' || true
import json, sys, os
layer, findings_dir = sys.argv[1], sys.argv[2]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
out_file = os.path.join(findings_dir, f"{layer}.jsonl")
with open(out_file, "a") as out:
    for dep in data.get("dependencies", []):
        for vuln in dep.get("vulns", []):
            out.write(json.dumps({
                "layer": layer, "severity": "high",
                "title": f"{dep['name']} {dep.get('version','')}: {vuln.get('id','')}",
                "file": "requirements.txt", "line": "",
                "rule": f"pip-audit:{vuln.get('id','')}",
                "fix": vuln.get("fix_versions", ["upgrade to latest"])[0] if vuln.get("fix_versions") else "upgrade",
                "doc_ref": "Camada 2 · Dependências"
            }) + "\n")
PY
  fi
fi

# 3. Go
if [ -f go.mod ]; then
  if need_cmd govulncheck "instale com 'go install golang.org/x/vuln/cmd/govulncheck@latest'"; then
    log_info "Rodando govulncheck..."
    govulncheck ./... 2>/dev/null | grep -E "^Vulnerability" | while read -r line; do
      add_finding "$LAYER" "high" "$line" "go.mod" "" "govulncheck" \
        "Atualize o módulo afetado" "Camada 2 · Dependências"
    done
  fi
fi

# 4. Trivy em containers (se houver Dockerfile)
if [ -f Dockerfile ] && need_cmd trivy "rode ./scripts/setup.sh"; then
  log_info "Trivy em Dockerfile (config)..."
  trivy config --severity CRITICAL,HIGH --format json . 2>/dev/null | \
    python3 - "$LAYER" "$FINDINGS_DIR" <<'PY' || true
import json, sys, os
layer, findings_dir = sys.argv[1], sys.argv[2]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
out_file = os.path.join(findings_dir, f"{layer}.jsonl")
with open(out_file, "a") as out:
    for r in data.get("Results", []):
        for m in r.get("Misconfigurations", []):
            sev = m.get("Severity", "MEDIUM").lower()
            if sev == "moderate": sev = "medium"
            out.write(json.dumps({
                "layer": layer, "severity": sev,
                "title": f"{m.get('ID','')}: {m.get('Title','')}",
                "file": r.get("Target",""), "line": str(m.get("CauseMetadata",{}).get("StartLine","")),
                "rule": f"trivy:{m.get('ID','')}",
                "fix": m.get("Resolution","Veja docs Trivy"),
                "doc_ref": "Camada 2 · Dependências"
            }) + "\n")
PY
fi

# 5. SBOM check
if [ ! -f sbom.json ] && [ ! -f sbom.xml ] && [ ! -d .sbom ]; then
  add_finding "$LAYER" "low" "SBOM não encontrado no repositório" \
    "" "" "deps:no-sbom" \
    "Gere SBOM com cyclonedx-npm, syft ou outra ferramenta" \
    "Camada 2 · Dependências — guia pág. 6"
fi

log_ok "Camada 02 concluída"

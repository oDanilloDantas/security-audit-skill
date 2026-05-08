#!/usr/bin/env bash
# scripts/render-report.sh
# Lê os findings de .security/findings/*.jsonl e gera o markdown final.
# Uso: ./render-report.sh [output-path]
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/_common.sh"

OUTPUT="${1:-.security/audit-$(date -u +%Y-%m-%d).md}"
TEMPLATE="$SKILL_DIR/templates/report.md.tpl"

if [ ! -f "$TEMPLATE" ]; then
  log_err "Template não encontrado: $TEMPLATE"
  exit 1
fi

python3 - "$FINDINGS_DIR" "$TEMPLATE" "$OUTPUT" "$(basename "$PWD")" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" <<'PY'
import json, sys, os
from collections import defaultdict, OrderedDict

findings_dir, template_path, output_path, project_name, run_date = sys.argv[1:6]

# Carrega todos os findings
all_findings = []
for fn in sorted(os.listdir(findings_dir) if os.path.isdir(findings_dir) else []):
    if not fn.endswith(".jsonl"): continue
    with open(os.path.join(findings_dir, fn)) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            try:
                all_findings.append(json.loads(line))
            except Exception:
                pass

# Ordena por severity → camada
sev_order = {"critical": 0, "high": 1, "medium": 2, "low": 3, "info": 4, "needs-review": 5}
all_findings.sort(key=lambda x: (sev_order.get(x.get("severity", "info"), 99), x.get("layer", ""), x.get("file", "")))

# Conta por severity
counts = defaultdict(int)
for f in all_findings:
    counts[f.get("severity", "info")] += 1

# Agrupa por camada
by_layer = OrderedDict()
LAYER_NAMES = OrderedDict([
    ("01-secrets",       "Camada 01 · Secrets & Credenciais"),
    ("02-dependencies",  "Camada 02 · Dependências & Supply Chain"),
    ("03-code",          "Camada 03 · Código & Lógica"),
    ("04-web-security",  "Camada 04 · Web Security & Headers"),
    ("05-auth",          "Camada 05 · Auth & AuthZ"),
    ("06-database",      "Camada 06 · Banco de Dados & PII"),
    ("07-cloud",         "Camada 07 · Cloud & Infraestrutura"),
    ("08-cicd",          "Camada 08 · CI/CD"),
    ("09-compliance",    "Camada 09 · Compliance & LGPD"),
])
for k in LAYER_NAMES: by_layer[k] = []
for f in all_findings:
    by_layer.setdefault(f.get("layer", "other"), []).append(f)

SEV_EMOJI = {
    "critical": "🔴",
    "high": "🟠",
    "medium": "🟡",
    "low": "🔵",
    "info": "⚪",
    "needs-review": "❔",
}

# Monta blocos do relatório
def render_layer(layer_id, name, items):
    if not items:
        return f"### {name}\n\n_Nenhum finding._\n"
    lines = [f"### {name}", ""]
    lines.append(f"_{len(items)} finding(s)_")
    lines.append("")
    for it in items:
        sev = it.get("severity", "info")
        emoji = SEV_EMOJI.get(sev, "•")
        title = it.get("title", "")
        file_ = it.get("file", "")
        line_ = it.get("line", "")
        rule = it.get("rule", "")
        fix = it.get("fix", "")
        doc = it.get("doc_ref", "")

        loc = ""
        if file_:
            loc = f" · `{file_}"
            if line_: loc += f":{line_}"
            loc += "`"

        lines.append(f"- {emoji} **[{sev.upper()}]** {title}{loc}")
        if rule: lines.append(f"  _Regra:_ `{rule}`")
        if fix:  lines.append(f"  _Como corrigir:_ {fix}")
        if doc:  lines.append(f"  _Referência:_ {doc}")
        lines.append("")
    return "\n".join(lines)

layers_md = []
for k, name in LAYER_NAMES.items():
    layers_md.append(render_layer(k, name, by_layer.get(k, [])))
layers_block = "\n\n".join(layers_md)

# Top 3 críticos
top_criticals = [f for f in all_findings if f.get("severity") == "critical"][:3]
if top_criticals:
    top_block = "\n".join(
        f"{i+1}. **{f.get('title','')}**" +
        (f" — `{f.get('file','')}{':'+f.get('line','') if f.get('line') else ''}`" if f.get("file") else "")
        for i, f in enumerate(top_criticals)
    )
else:
    top_block = "_Nenhum issue crítico — bom sinal, mas confira high & needs-review abaixo._"

# Lê template
tpl = open(template_path).read()

# Substitui placeholders
out = (tpl
    .replace("{{PROJECT_NAME}}", project_name)
    .replace("{{RUN_DATE}}", run_date)
    .replace("{{COUNT_CRITICAL}}", str(counts.get("critical", 0)))
    .replace("{{COUNT_HIGH}}", str(counts.get("high", 0)))
    .replace("{{COUNT_MEDIUM}}", str(counts.get("medium", 0)))
    .replace("{{COUNT_LOW}}", str(counts.get("low", 0) + counts.get("info", 0)))
    .replace("{{COUNT_REVIEW}}", str(counts.get("needs-review", 0)))
    .replace("{{TOP_CRITICALS}}", top_block)
    .replace("{{LAYERS}}", layers_block)
)

os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
with open(output_path, "w") as f:
    f.write(out)
print(f"OK {output_path}")
PY

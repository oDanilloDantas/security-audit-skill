#!/usr/bin/env bash
# scripts/audit.sh
# Orquestra todos os scans das 9 camadas e gera relatório final.
#
# Uso:
#   ./scripts/audit.sh                  # roda tudo
#   ./scripts/audit.sh --gate=critical  # falha se houver critical (CI)
#   ./scripts/audit.sh --skip=07,08     # pula camadas
#   ./scripts/audit.sh --layer=01       # roda só uma camada

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/_common.sh"

# Args
GATE=""
SKIP=""
ONLY=""
for arg in "$@"; do
  case "$arg" in
    --gate=*)  GATE="${arg#*=}" ;;
    --skip=*)  SKIP="${arg#*=}" ;;
    --layer=*) ONLY="${arg#*=}" ;;
    --help|-h)
      cat <<EOF
Security Audit · 9 Camadas

Uso: $0 [opções]
  --gate=critical|high|medium  Falha o exit code se houver findings dessa severity ou pior
  --skip=01,02,03              Pula camadas (números separados por vírgula)
  --layer=01                   Roda apenas uma camada
  --help                       Mostra esta ajuda
EOF
      exit 0
      ;;
  esac
done

# Bandeira de skip
if [ -f .security/skip-audit ]; then
  log_warn "Arquivo .security/skip-audit encontrado — auditoria abortada"
  exit 0
fi

# Limpa findings anteriores
rm -rf "$FINDINGS_DIR"
mkdir -p "$FINDINGS_DIR"

# Cabeçalho
log_step "🔒 Security Audit · 9 Camadas"
log_info "Projeto: $(basename "$PWD")"
log_info "Detectado: $(detect_project_kind)"
log_info "Data: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Lista de camadas e seus scripts
declare -a LAYERS=(
  "01:secrets:scan-secrets.sh"
  "02:dependencies:scan-deps.sh"
  "03:code:scan-code.sh"
  "04:web-security:scan-web.sh"
  "05:auth:scan-auth.sh"
  "06:database:scan-db.sh"
  "07:cloud:scan-cloud.sh"
  "08:cicd:scan-cicd.sh"
  "09:compliance:scan-compliance.sh"
)

# Roda cada camada
for entry in "${LAYERS[@]}"; do
  IFS=':' read -r num name script <<< "$entry"

  # --layer filter
  if [ -n "$ONLY" ] && [ "$ONLY" != "$num" ]; then continue; fi
  # --skip filter
  if [[ ",$SKIP," == *",$num,"* ]]; then
    log_info "Pulando camada $num ($name) — pedido"
    continue
  fi

  if [ -x "$SCRIPT_DIR/$script" ]; then
    "$SCRIPT_DIR/$script" || log_warn "Camada $num retornou erro (continuando)"
  else
    log_warn "Script $script não encontrado ou não executável"
  fi
done

# Gera relatório
log_step "Gerando relatório"
REPORT_DATE=$(date -u +%Y-%m-%d)
REPORT_FILE="$SECURITY_DIR/audit-$REPORT_DATE.md"
"$SCRIPT_DIR/render-report.sh" "$REPORT_FILE" || {
  log_err "Falha ao gerar relatório"
  exit 2
}
log_ok "Relatório salvo: $REPORT_FILE"

# Sumário no terminal
log_step "Sumário"
declare -A COUNT=([critical]=0 [high]=0 [medium]=0 [low]=0 [info]=0 [needs-review]=0)
for f in "$FINDINGS_DIR"/*.jsonl; do
  [ -f "$f" ] || continue
  while IFS= read -r line; do
    sev=$(echo "$line" | python3 -c "import sys, json; print(json.loads(sys.stdin.read())['severity'])" 2>/dev/null || echo "")
    [ -n "$sev" ] && COUNT[$sev]=$((${COUNT[$sev]:-0} + 1))
  done < "$f"
done

echo
echo -e "  ${C_RED}🔴 Critical:${C_RESET}     ${COUNT[critical]}"
echo -e "  ${C_YELLOW}🟠 High:${C_RESET}         ${COUNT[high]}"
echo -e "  ${C_YELLOW}🟡 Medium:${C_RESET}       ${COUNT[medium]}"
echo -e "  ${C_BLUE}🔵 Low/Info:${C_RESET}     $((${COUNT[low]} + ${COUNT[info]}))"
echo -e "  ${C_GRAY}⚪ Needs review:${C_RESET} ${COUNT[needs-review]}"
echo

# Aplica gate se pedido
EXIT=0
case "$GATE" in
  critical) [ "${COUNT[critical]}" -gt 0 ] && EXIT=1 ;;
  high)     [ $((${COUNT[critical]} + ${COUNT[high]})) -gt 0 ] && EXIT=1 ;;
  medium)   [ $((${COUNT[critical]} + ${COUNT[high]} + ${COUNT[medium]})) -gt 0 ] && EXIT=1 ;;
esac

if [ "$EXIT" -ne 0 ]; then
  log_err "Gate '$GATE' acionado — exit $EXIT"
fi

exit $EXIT

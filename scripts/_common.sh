#!/usr/bin/env bash
# scripts/_common.sh
# Helpers compartilhados por todos os scan scripts.
# Uso: source "$(dirname "$0")/_common.sh"

set -uo pipefail

# Cores (só ativa se stdout é tty)
if [ -t 1 ]; then
  C_RESET='\033[0m'
  C_RED='\033[0;31m'
  C_YELLOW='\033[1;33m'
  C_GREEN='\033[0;32m'
  C_BLUE='\033[0;34m'
  C_GRAY='\033[0;90m'
  C_BOLD='\033[1m'
else
  C_RESET='' C_RED='' C_YELLOW='' C_GREEN='' C_BLUE='' C_GRAY='' C_BOLD=''
fi

# Diretórios padrão
SECURITY_DIR="${SECURITY_DIR:-.security}"
FINDINGS_DIR="$SECURITY_DIR/findings"
mkdir -p "$FINDINGS_DIR"

# Logging
log_info()  { echo -e "${C_BLUE}ℹ${C_RESET} $*" >&2; }
log_ok()    { echo -e "${C_GREEN}✓${C_RESET} $*" >&2; }
log_warn()  { echo -e "${C_YELLOW}⚠${C_RESET} $*" >&2; }
log_err()   { echo -e "${C_RED}✗${C_RESET} $*" >&2; }
log_step()  { echo -e "\n${C_BOLD}▸ $*${C_RESET}" >&2; }

# Verifica se um comando existe; se não, sugere instalação e retorna 1
need_cmd() {
  local cmd="$1"
  local hint="${2:-instale a ferramenta antes de continuar}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log_warn "$cmd não está instalado — $hint"
    return 1
  fi
  return 0
}

# Detecta o tipo de projeto e popula a variável global PROJECT_KIND
detect_project_kind() {
  PROJECT_KIND="unknown"
  [ -f package.json ]                          && PROJECT_KIND="node"
  [ -f pyproject.toml ] || [ -f requirements.txt ] && PROJECT_KIND="python"
  [ -f go.mod ]                                && PROJECT_KIND="go"
  [ -f Gemfile ]                               && PROJECT_KIND="ruby"
  [ -f pom.xml ] || [ -f build.gradle ]        && PROJECT_KIND="java"
  [ -f Cargo.toml ]                            && PROJECT_KIND="rust"
  echo "$PROJECT_KIND"
}

# Adiciona um finding ao JSON da camada atual
# Uso: add_finding LAYER SEVERITY TITLE FILE LINE RULE FIX DOC_REF
# Severity: critical | high | medium | low | info | needs-review
add_finding() {
  local layer="$1" severity="$2" title="$3"
  local file="${4:-}" line="${5:-}" rule="${6:-}"
  local fix="${7:-}" doc_ref="${8:-}"

  local out="$FINDINGS_DIR/${layer}.jsonl"
  # Escapa para JSON usando python (mais seguro que sed)
  python3 -c "
import json, sys
print(json.dumps({
  'layer': '''$layer''',
  'severity': '''$severity''',
  'title': '''$title''',
  'file': '''$file''',
  'line': '''$line''',
  'rule': '''$rule''',
  'fix': '''$fix''',
  'doc_ref': '''$doc_ref'''
}))" >> "$out"
}

# Cabeçalho de scan
scan_header() {
  local layer="$1" name="$2"
  log_step "Camada $layer · $name"
}

export -f log_info log_ok log_warn log_err log_step
export -f need_cmd detect_project_kind add_finding scan_header

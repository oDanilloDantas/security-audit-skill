#!/usr/bin/env bash
# scripts/setup.sh
# Instala as ferramentas externas usadas pelos scans.
# Detecta SO automaticamente (macOS via brew, Linux via apt/yum, Alpine via apk).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

log_step "Security Audit Skill · Setup"

# Detecta o gerenciador de pacotes
PKG=""
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v brew >/dev/null; then
    log_err "Homebrew não encontrado. Instale em https://brew.sh"
    exit 1
  fi
  PKG="brew"
elif command -v apt >/dev/null; then PKG="apt"
elif command -v yum >/dev/null; then PKG="yum"
elif command -v apk >/dev/null; then PKG="apk"
else
  log_err "Não consegui detectar gerenciador de pacotes. Instale manual."
  exit 1
fi

log_info "Gerenciador detectado: $PKG"

# Lista de ferramentas necessárias e seus pacotes em cada PKG
# Formato: "comando|brew_pkg|apt_pkg"
TOOLS=(
  "gitleaks|gitleaks|gitleaks"
  "trufflehog|trufflehog|trufflehog"
  "trivy|trivy|trivy"
  "semgrep|semgrep|semgrep"
  "jq|jq|jq"
)

install_one() {
  local cmd="$1" brew_pkg="$2" apt_pkg="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    log_ok "$cmd já instalado"
    return
  fi
  log_info "Instalando $cmd..."
  case "$PKG" in
    brew) brew install "$brew_pkg" || log_warn "Falhou: $cmd" ;;
    apt)  sudo apt-get install -y "$apt_pkg" 2>/dev/null || \
          log_warn "Pacote $apt_pkg não disponível no apt; instale manual: https://github.com/$cmd/$cmd" ;;
    yum)  sudo yum install -y "$cmd" 2>/dev/null || log_warn "Falhou via yum" ;;
    apk)  sudo apk add --no-cache "$cmd" || log_warn "Falhou via apk" ;;
  esac
}

for entry in "${TOOLS[@]}"; do
  IFS='|' read -r cmd brew_pkg apt_pkg <<< "$entry"
  install_one "$cmd" "$brew_pkg" "$apt_pkg"
done

# Snyk via npm (opcional)
if command -v npm >/dev/null 2>&1; then
  if ! command -v snyk >/dev/null 2>&1; then
    log_info "Instalando Snyk via npm..."
    npm install -g snyk 2>/dev/null || log_warn "Falhou (pode precisar sudo)"
  else
    log_ok "snyk já instalado"
  fi
fi

# Prowler via pip (opcional)
if command -v pip3 >/dev/null 2>&1 || command -v pipx >/dev/null 2>&1; then
  if ! command -v prowler >/dev/null 2>&1; then
    log_info "Instalando Prowler..."
    if command -v pipx >/dev/null 2>&1; then
      pipx install prowler 2>/dev/null || log_warn "Falhou via pipx"
    else
      pip3 install prowler --break-system-packages 2>/dev/null || pip3 install prowler 2>/dev/null || log_warn "Falhou via pip"
    fi
  else
    log_ok "prowler já instalado"
  fi
fi

echo
log_step "Resumo da instalação"
for entry in "${TOOLS[@]}"; do
  IFS='|' read -r cmd _ _ <<< "$entry"
  if command -v "$cmd" >/dev/null; then log_ok "$cmd"; else log_warn "$cmd (não instalado)"; fi
done
for opt in snyk prowler tfsec checkov; do
  if command -v "$opt" >/dev/null; then log_ok "$opt (opcional)"; fi
done

echo
log_info "Setup concluído. Rode './scripts/audit.sh' pra começar."

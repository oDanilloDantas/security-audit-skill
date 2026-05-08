#!/usr/bin/env bash
# scripts/scan-cicd.sh
# Camada 08 · CI/CD & Supply Chain Interna
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

scan_header "08" "CI/CD & Supply Chain Interna"
LAYER="08-cicd"

# 1. GitHub Actions workflows
WORKFLOWS=$(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null | head -50)
for wf in $WORKFLOWS; do
  [ -f "$wf" ] || continue

  # 1.1 Actions sem pin por SHA (usando @v1, @master, @main)
  TAG_PINS=$(grep -nE "uses:\s*[a-zA-Z0-9-]+/[a-zA-Z0-9-]+@(v[0-9]+|main|master|HEAD)" "$wf" 2>/dev/null | head -10 || true)
  if [ -n "$TAG_PINS" ]; then
    echo "$TAG_PINS" | while IFS=: read -r line _; do
      add_finding "$LAYER" "medium" "Action pinada por tag/branch (mutável) ao invés de SHA" \
        "$wf" "$line" "cicd:action-tag-pin" \
        "Pin por SHA: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11" \
        "Camada 8 · CI/CD — guia pág. 18-19"
    done
  fi

  # 1.2 pull_request_target com checkout do head
  if grep -q "pull_request_target" "$wf" 2>/dev/null; then
    if grep -A 20 "pull_request_target" "$wf" 2>/dev/null | grep -q "head.sha\|head.ref"; then
      add_finding "$LAYER" "critical" "pull_request_target faz checkout do head do PR (PR injection)" \
        "$wf" "" "cicd:prt-injection" \
        "Use 'on: pull_request' ou separe jobs sem secrets pra rodar código do fork" \
        "Camada 8 · CI/CD — guia pág. 19"
    else
      add_finding "$LAYER" "needs-review" "pull_request_target detectado — verifique se não roda código do PR" \
        "$wf" "" "cicd:prt-review" \
        "pull_request_target tem secrets; nunca rode código não-revisado do PR" \
        "Camada 8 · CI/CD"
    fi
  fi

  # 1.3 echo de secret em log
  if grep -nE "echo.*\\\$\{?\{?\s*secrets\." "$wf" 2>/dev/null | head -3 | while IFS=: read -r line _; do
    add_finding "$LAYER" "high" "Workflow imprime secret em log" \
      "$wf" "$line" "cicd:echo-secret" \
      "Nunca echo de secrets; use action-mask ou ::add-mask::" \
      "Camada 8 · CI/CD"
  done; then :; fi

  # 1.4 GITHUB_TOKEN sem permissions explícitas
  if ! grep -qE "^permissions:" "$wf" 2>/dev/null && ! grep -qE "^\s+permissions:" "$wf" 2>/dev/null; then
    add_finding "$LAYER" "medium" "Workflow sem 'permissions' explícitas (usa default amplo)" \
      "$wf" "" "cicd:no-permissions" \
      "Defina 'permissions: contents: read' no topo; abra apenas o necessário" \
      "Camada 8 · CI/CD"
  fi
done

# 2. Branch protection — heurística (verifica se há .github/CODEOWNERS)
if [ -d .github ] || [ -d .git ]; then
  if [ ! -f .github/CODEOWNERS ] && [ ! -f CODEOWNERS ]; then
    add_finding "$LAYER" "low" "CODEOWNERS não encontrado" \
      "" "" "cicd:no-codeowners" \
      "Crie .github/CODEOWNERS apontando reviewers para paths sensíveis" \
      "Camada 8 · CI/CD"
  fi
fi

# 3. .gitlab-ci.yml
if [ -f .gitlab-ci.yml ]; then
  if grep -nE "echo.*\$.*_TOKEN|echo.*\$.*_SECRET" .gitlab-ci.yml 2>/dev/null | head -3 | while IFS=: read -r line _; do
    add_finding "$LAYER" "high" "GitLab CI imprime secret em log" \
      ".gitlab-ci.yml" "$line" "cicd:gitlab-echo-secret" \
      "Use 'masked' nos protected variables; nunca echo" \
      "Camada 8 · CI/CD"
  done; then :; fi
fi

log_ok "Camada 08 concluída"

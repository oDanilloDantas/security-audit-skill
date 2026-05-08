#!/usr/bin/env bash
# scripts/scan-compliance.sh
# Camada 09 · Compliance & LGPD
# Faz checks DOCUMENTAIS — confirma se documentos exigidos existem.
# Não substitui auditoria humana de compliance.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

scan_header "09" "Compliance & LGPD"
LAYER="09-compliance"

log_info "Esta camada verifica artefatos documentais. Auditoria de compliance real exige humano."

# 1. Política de Privacidade
PRIVACY_FOUND=false
for f in PRIVACY.md PRIVACY-POLICY.md privacy.md docs/privacy.md \
         POLITICA-PRIVACIDADE.md politica-privacidade.md \
         legal/privacy.md docs/legal/privacy.md; do
  if [ -f "$f" ]; then PRIVACY_FOUND=true; break; fi
done
if ! $PRIVACY_FOUND; then
  add_finding "$LAYER" "medium" "Política de Privacidade não encontrada no repositório" \
    "" "" "compliance:no-privacy-policy" \
    "Publique política de privacidade (LGPD art. 9). Pode ficar em /privacy ou em CMS externo." \
    "Camada 9 · Compliance — guia pág. 20"
else
  log_ok "Política de Privacidade encontrada"
fi

# 2. Termo de Uso
TERMS_FOUND=false
for f in TERMS.md TERMS-OF-USE.md terms.md docs/terms.md \
         TERMO-USO.md termo-uso.md legal/terms.md; do
  if [ -f "$f" ]; then TERMS_FOUND=true; break; fi
done
if ! $TERMS_FOUND; then
  add_finding "$LAYER" "low" "Termo de Uso não encontrado" \
    "" "" "compliance:no-terms" \
    "Publique Termo de Uso separado da Política de Privacidade" \
    "Camada 9 · Compliance"
fi

# 3. SECURITY.md (responsible disclosure)
if [ ! -f SECURITY.md ] && [ ! -f .github/SECURITY.md ]; then
  add_finding "$LAYER" "low" "SECURITY.md ausente (canal de disclosure)" \
    "" "" "compliance:no-security-md" \
    "Crie SECURITY.md com canal pra reports de vulnerabilidade" \
    "Camada 9 · Compliance"
fi

# 4. Cookie banner / consent — heurística no frontend
if [ -d src ] || [ -d app ] || [ -d pages ]; then
  COOKIE_LIB=$(grep -rE "cookie-consent|cookieconsent|cookiebot|onetrust|@osano" \
    --include="*.{js,ts,jsx,tsx,html,json}" \
    --exclude-dir={node_modules,.git,dist,build,.next} . 2>/dev/null | head -3 || true)
  if [ -z "$COOKIE_LIB" ]; then
    add_finding "$LAYER" "needs-review" "Nenhuma lib de cookie consent detectada (verifique se há banner customizado)" \
      "" "" "compliance:no-cookie-banner" \
      "Implemente cookie banner com opt-in granular pra cookies não-essenciais" \
      "Camada 9 · Compliance"
  fi
fi

# 5. DPA template
DPA_FOUND=false
for f in DPA.md docs/dpa.md legal/dpa.md templates/dpa.md; do
  [ -f "$f" ] && DPA_FOUND=true
done
if ! $DPA_FOUND && [ -f package.json ]; then
  # Sinaliza só se for SaaS B2B (heurística)
  if grep -qiE "saas|b2b|enterprise|tenant" package.json 2>/dev/null; then
    add_finding "$LAYER" "low" "DPA template não encontrado (recomendado pra SaaS B2B)" \
      "" "" "compliance:no-dpa-template" \
      "Crie DPA modelo para fornecer a clientes empresariais que tratam dados pessoais" \
      "Camada 9 · Compliance — guia pág. 21"
  fi
fi

# 6. Endpoints de privacidade na API (8 direitos LGPD)
if [ -d src ] || [ -d app ]; then
  PRIVACY_ENDPOINTS=$(grep -rE "/privacy/(me|data|export|delete|account|sharing|anonymize)" \
    --include="*.{js,ts,py,go,rb}" \
    --exclude-dir={node_modules,.git,dist,build,.next,__pycache__} . 2>/dev/null | head -3 || true)
  if [ -z "$PRIVACY_ENDPOINTS" ]; then
    add_finding "$LAYER" "needs-review" "Sem endpoints aparentes pra exercer direitos LGPD" \
      "" "" "compliance:no-privacy-endpoints" \
      "Implemente GET /privacy/data (acesso), DELETE /privacy/account (eliminação), GET /privacy/export (portabilidade), etc. Veja Apêndice D do guia." \
      "Camada 9 · Compliance — guia pág. 21"
  fi
fi

# 7. Retention policy (heurística)
if ! grep -rE "retention|expir.*after|TTL|deleteAfter" \
     --include="*.{js,ts,py,go,sql,prisma}" \
     --exclude-dir={node_modules,.git,dist,build,__pycache__,target} \
     . 2>/dev/null | head -1 >/dev/null; then
  add_finding "$LAYER" "low" "Sem política de retenção aparente no código" \
    "" "" "compliance:no-retention" \
    "LGPD art. 16: dados devem ser eliminados após o tratamento. Documente e implemente." \
    "Camada 9 · Compliance"
fi

log_ok "Camada 09 concluída (lembre-se: compliance real exige humano)"

#!/usr/bin/env bash
# scripts/scan-web.sh
# Camada 04 · Web Security & Headers
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

scan_header "04" "Web Security & Headers"
LAYER="04-web-security"

# 1. Express + Helmet check
if [ -f package.json ]; then
  if grep -q '"express"' package.json 2>/dev/null; then
    if ! grep -q '"helmet"' package.json 2>/dev/null; then
      add_finding "$LAYER" "high" "Express detectado mas sem helmet (security headers)" \
        "package.json" "" "web:no-helmet" \
        "Instale helmet: npm i helmet; use app.use(helmet({...}))" \
        "Camada 4 · Web Security — guia pág. 10-11"
      log_warn "Express sem Helmet"
    else
      log_ok "Helmet presente"
    fi

    # cors com credentials + origin *
    CORS_BAD=$(grep -rEnH --include="*.{js,ts}" \
      --exclude-dir={node_modules,dist,build} \
      "origin\s*:\s*['\"]?\*['\"]?.*credentials.*true|credentials\s*:\s*true.*origin\s*:\s*['\"]?\*" \
      . 2>/dev/null | head -5 || true)
    if [ -n "$CORS_BAD" ]; then
      echo "$CORS_BAD" | while IFS=: read -r file line _; do
        add_finding "$LAYER" "high" "CORS com '*' e credentials: true (proibido pelo navegador)" \
          "$file" "$line" "web:cors-wildcard-creds" \
          "Use allowlist explícita de origins" "Camada 4 · Web Security"
      done
    fi
  fi

  # Rate limiting check
  if ! grep -qE '"express-rate-limit"|"@nestjs/throttler"|"rate-limiter-flexible"' package.json 2>/dev/null; then
    if grep -q '"express"\|"fastify"\|"@nestjs/' package.json 2>/dev/null; then
      add_finding "$LAYER" "medium" "Sem biblioteca de rate limit detectada" \
        "package.json" "" "web:no-rate-limit" \
        "Adicione express-rate-limit ou similar; aplique em login, signup, password reset" \
        "Camada 4 · Web Security — guia pág. 11"
    fi
  fi
fi

# 2. Django settings
if [ -f manage.py ]; then
  SETTINGS=$(find . -name "settings.py" -not -path "*/node_modules/*" 2>/dev/null | head -3)
  for s in $SETTINGS; do
    grep -q "SECURE_HSTS_SECONDS" "$s" 2>/dev/null || \
      add_finding "$LAYER" "medium" "Django sem SECURE_HSTS_SECONDS" \
        "$s" "" "web:django-no-hsts" \
        "Defina SECURE_HSTS_SECONDS = 31536000" "Camada 4 · Web Security"

    grep -q "SECURE_SSL_REDIRECT.*True" "$s" 2>/dev/null || \
      add_finding "$LAYER" "high" "Django sem SECURE_SSL_REDIRECT" \
        "$s" "" "web:django-no-ssl-redirect" \
        "Defina SECURE_SSL_REDIRECT = True" "Camada 4 · Web Security"

    grep -q "DEBUG\s*=\s*False" "$s" 2>/dev/null || \
      add_finding "$LAYER" "needs-review" "Django settings: confirme DEBUG=False em produção" \
        "$s" "" "web:django-debug" \
        "DEBUG = False em settings de produção" "Camada 4 · Web Security"
  done
fi

# 3. Next.js — config
if [ -f next.config.js ] || [ -f next.config.ts ] || [ -f next.config.mjs ]; then
  CFG=$(ls next.config.* 2>/dev/null | head -1)
  if ! grep -q "headers" "$CFG" 2>/dev/null; then
    add_finding "$LAYER" "medium" "Next.js sem headers() em next.config" \
      "$CFG" "" "web:next-no-headers" \
      "Adicione async headers() retornando array com CSP, HSTS, X-Frame-Options" \
      "Camada 4 · Web Security — guia pág. 11"
  fi
fi

# 4. Nginx config
NGINX_CONFS=$(find . -name "nginx.conf" -o -name "*.nginx" 2>/dev/null | head -5)
for c in $NGINX_CONFS; do
  grep -q "ssl_protocols.*TLSv1\.0\|ssl_protocols.*TLSv1\.1" "$c" 2>/dev/null && \
    add_finding "$LAYER" "high" "Nginx com TLS 1.0/1.1 habilitado" \
      "$c" "" "web:nginx-old-tls" \
      "Restrinja a 'TLSv1.2 TLSv1.3'" "Camada 4 · Web Security"

  grep -q "add_header Strict-Transport-Security" "$c" 2>/dev/null || \
    add_finding "$LAYER" "medium" "Nginx sem header HSTS" \
      "$c" "" "web:nginx-no-hsts" \
      "Adicione: add_header Strict-Transport-Security 'max-age=31536000; includeSubDomains' always;" \
      "Camada 4 · Web Security"
done

log_ok "Camada 04 concluída"

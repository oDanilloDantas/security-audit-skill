# Camada 04 · Web Security & Headers

> **O que esta camada cobre:** headers HTTP que dizem ao browser o que ele pode e não pode fazer com seu site (CSP, HSTS, SameSite cookies), CORS, rate limiting, TLS, WAF.

## Checklist completo (26 itens)

### Básico (B)
- [ ] HTTPS forçado em todas as rotas, redirect 301 de HTTP
- [ ] Header `Strict-Transport-Security` com `max-age=31536000; includeSubDomains`
- [ ] `X-Content-Type-Options: nosniff` em todas as respostas
- [ ] `X-Frame-Options: DENY` ou `CSP frame-ancestors` definido
- [ ] `Referrer-Policy: strict-origin-when-cross-origin` ou mais restritivo
- [ ] Cookies de sessão com `Secure`, `HttpOnly` e `SameSite=Lax` ou `Strict`
- [ ] CORS configurado com allowlist explícita de origins, jamais `*` com credentials
- [ ] Rate limit em endpoints de login, signup e password reset (5–10 req/min)

### Médio (M)
- [ ] CSP completo com nonces para inline scripts, sem `unsafe-inline` nem `unsafe-eval`
- [ ] CSP report-uri ou report-to configurado, alertas no SIEM
- [ ] CSRF protection em forms — token sincronizado ou double submit cookie
- [ ] SubResource Integrity (SRI) em scripts/CSS de CDN externo
- [ ] Rate limit por IP + por usuário autenticado, com bucket diferente para endpoints custosos
- [ ] WAF (Cloudflare, AWS WAF, Imperva) em frente à origin
- [ ] Permissions-Policy restringe acesso a câmera, microfone, geolocation só onde necessário
- [ ] Cross-Origin-Opener-Policy (COOP) e Cross-Origin-Embedder-Policy (COEP) configurados se app é sensível
- [ ] Domínio adicionado ao HSTS preload list (hstspreload.org)
- [ ] Cookies sensíveis com prefix `__Host-` ou `__Secure-`
- [ ] Bot detection (hCaptcha, Turnstile) em endpoints públicos críticos
- [ ] TLS 1.3 obrigatório, TLS 1.0 e 1.1 desabilitados, ciphers forward-secrecy only
- [ ] Certificado monitorado — alerta com 30 dias de antecedência

### Sênior (S)
- [ ] CSP em modo enforce, não só report-only, com tracking de violações
- [ ] Trusted Types habilitado para mitigar DOM XSS
- [ ] Anti-bot avançado (PerimeterX, DataDome) em endpoints de e-commerce/login
- [ ] Certificate Transparency monitoring — alerta se cert do seu domínio for emitido por terceiros
- [ ] CAA record no DNS restringe quais CAs podem emitir cert pro seu domínio

## Comandos & ferramentas

```bash
# Auditoria rápida de headers
curl -I https://app.com | grep -iE "strict|x-frame|csp|referrer"

# Mozilla Observatory · SSL Labs · testssl.sh
# https://observatory.mozilla.org/analyze/app.com
# https://www.ssllabs.com/ssltest/analyze.html?d=app.com
testssl.sh --full https://app.com
```

## Headers ideais (Express + Helmet)

```javascript
const helmet = require('helmet');
app.use(helmet({
  contentSecurityPolicy: { directives: {
    defaultSrc: ["'self'"],
    scriptSrc:  ["'self'", (req, res) => `'nonce-${res.locals.nonce}'`],
    styleSrc:   ["'self'", "'unsafe-inline'"],
    imgSrc:     ["'self'", "data:", "https://cdn.app.com"],
    frameAncestors: ["'none'"],
    reportUri: "/csp-report"
  }},
  hsts: { maxAge: 31536000, includeSubDomains: true, preload: true },
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' }
}));
```

## Cookie seguro

```javascript
res.cookie('__Host-session', sessionId, {
  httpOnly: true, secure: true, sameSite: 'lax',
  path: '/', maxAge: 15 * 60 * 1000
});
```

## Rate limit (express-rate-limit + Redis)

```javascript
const loginLimiter = rateLimit({
  store: new RedisStore({ client: redis }),
  windowMs: 15 * 60 * 1000, max: 5,
  keyGenerator: req => `${req.ip}:${req.body.email}`
});
app.post('/login', loginLimiter, loginHandler);
```

## Sinais de equipe imatura

- "A gente tem CORS configurado, tá protegido" — CORS não é proteção, é permissão
- "CSP quebra muita coisa, deixa report-only" — report-only nunca vai pra enforce
- "Login não tem captcha porque atrapalha conversão" — até a primeira invasão
- "A gente usa SSL" — TLS 1.0 com cifra fraca também é "SSL"
- "CSRF? Estamos numa SPA, não precisa" — endpoints state-changing precisam, sim

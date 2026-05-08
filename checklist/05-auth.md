# Camada 05 · Auth & AuthZ

> **O que esta camada cobre:** autenticação (provar quem você é) e autorização (decidir o que você pode fazer). JWT, OAuth, MFA, refresh tokens, RBAC, ABAC.

## Checklist completo (28 itens)

### Básico (B)
- [ ] Senhas com mínimo 12 caracteres, banidas as top 10k mais comuns (zxcvbn ou Have I Been Pwned)
- [ ] Bcrypt com cost ≥ 12 ou Argon2id com params recomendados pela OWASP
- [ ] JWT valida explicitamente o `alg` esperado, rejeita `none`
- [ ] JWT secrets/keys diferentes entre ambientes; chaves RS256 para apps multi-serviço
- [ ] Tokens de session/refresh têm `exp` definido — máximo 30 dias para refresh
- [ ] Logout invalida sessão server-side, não só limpa cookie
- [ ] Login enumeration mitigado — mensagem genérica "credenciais inválidas"

### Médio (M)
- [ ] MFA disponível para todos os usuários (TOTP, WebAuthn)
- [ ] MFA **obrigatório** para usuários admin/staff
- [ ] Refresh token rotation: cada uso invalida o anterior, detecta replay
- [ ] Token reuse detection: se refresh token antigo for usado, revoga toda a sessão
- [ ] Email de notificação em mudanças sensíveis: senha, email, MFA, novo dispositivo
- [ ] Account lockout temporário após N falhas, com unlock timer ou suporte
- [ ] Reset password usa token single-use que expira em < 30 min
- [ ] OAuth: state param obrigatório, redirect URI em allowlist exata (não wildcard)
- [ ] OAuth: PKCE habilitado para clients públicos (mobile, SPA)
- [ ] Sessões listáveis pelo usuário, com opção de "encerrar todas as outras"
- [ ] RBAC com roles definidas, não permissões espalhadas no código
- [ ] Audit log de login: quando, IP, user-agent, sucesso/falha, com geolocation
- [ ] Detecção de impossible travel — login em SP às 14h e em Tóquio às 14h05 alarma

### Sênior (S)
- [ ] WebAuthn / Passkeys disponível como segundo fator (ou primário, passwordless)
- [ ] ABAC para autorização contextual (location, time, device trust)
- [ ] Step-up authentication: ações sensíveis (transferência, mudança de admin) pedem MFA novamente
- [ ] Risk-based authentication: device fingerprint + behavior baseline
- [ ] Just-in-time access para admin (Teleport, AWS SSO com session limit)
- [ ] Política de revogação de acesso ≤ 24h após desligamento (offboarding automatizado)
- [ ] SCIM provisioning entre IdP (Okta, Azure AD) e apps SaaS
- [ ] Anti-phishing: notification em qualquer login com hardware key (hardware-bound)

## Comandos & ferramentas

```bash
# Verifica se senhas estão em vazamentos públicos
curl https://api.pwnedpasswords.com/range/$(echo -n "minha-senha" | sha1sum | cut -c1-5)

# Decode e inspeção de JWT (não confie no payload)
jwt-cli decode "eyJhbGciOiJIUzI1NiI..."

# OAuth flow tester
oauth-utils verify-pkce --client-id=...
```

## JWT seguro — antes & depois

### Antes (aceita qualquer alg)
```javascript
const decoded = jwt.verify(token, secret);  // 🚨 aceita "none"
```

### Depois (alg fixo)
```javascript
const decoded = jwt.verify(token, publicKey, {
  algorithms: ['RS256'],          // fixo, não negociável
  issuer: 'https://auth.app.com',
  audience: 'app-api',
  clockTolerance: 10
});
```

## Refresh token rotation com detecção de reuso

```javascript
async function rotateRefreshToken(oldToken) {
  const stored = await db.findToken(oldToken);
  if (!stored || stored.used) {
    // Token reuse detected — atacante tem token antigo
    await db.revokeAllUserSessions(stored?.userId);
    throw new Error('token reuse detected');
  }
  await db.markTokenUsed(oldToken);
  return generateNewTokenPair(stored.userId);
}
```

## RBAC com Casbin

```ini
# model.conf — matcher
m = r.sub == p.sub && keyMatch(r.obj, p.obj) && r.act == p.act

# policy.csv
p, admin, /api/*,           *
p, user,  /api/orders/:id,  read
p, user,  /api/orders,      create
```

## Sinais de equipe imatura

- "JWT é stateless, dá pra invalidar não" — usar deny list ou revogar a chave de assinatura
- "MFA é chato pro usuário" — até o usuário perder a conta e culpar você
- "Nossa role admin pode tudo" — princípio do menor privilégio é pra todos
- "A gente confia no token uma vez emitido" — refresh tokens precisam de rotação
- "OAuth usa redirect URI com wildcard" — open redirect virando token leak

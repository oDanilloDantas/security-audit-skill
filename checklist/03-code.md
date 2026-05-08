# Camada 03 · Código & Lógica de Aplicação

> **O que esta camada cobre:** vulnerabilidades no código da aplicação — onde dev confia em dado de usuário sem validar, autoriza ações sem checar permissão, ou aplica criptografia errada.

## Checklist completo (30 itens)

### Básico (B)
- [ ] Todo input do usuário é validado por schema (Zod, Joi, Pydantic, class-validator)
- [ ] Queries SQL usam **prepared statements**, jamais concatenação de strings
- [ ] Output em HTML usa template engine que escapa por padrão (React, Vue, Jinja2, ERB)
- [ ] Autenticação é checada em todo endpoint (middleware), não rota a rota
- [ ] Senha é hasheada com bcrypt/argon2/scrypt — nunca MD5, SHA1, SHA256 puro
- [ ] Erros não vazam stack trace pro cliente em produção
- [ ] Endpoints retornam 401/403/404 corretos — não 500 com detalhes

### Médio (M)
- [ ] Autorização (BOLA): cada acesso a recurso checa **ownership** — usuário X só vê dados de X
- [ ] Endpoints administrativos têm checagem de role (BFLA), não só autenticação
- [ ] Mass assignment bloqueado: DTOs explícitos definem o que o cliente pode enviar
- [ ] Upload de arquivo valida MIME real (magic bytes), não só extensão
- [ ] Upload tem limite de tamanho, anti-vírus (ClamAV) e armazenamento fora da raiz da web
- [ ] SSRF: requests para URLs externas têm allowlist de domínios; bloqueia ranges privados (169.254.169.254, 127.0.0.0/8, 10.0.0.0/8)
- [ ] XXE desabilitado em parsers XML — entidades externas bloqueadas
- [ ] Path traversal: nomes de arquivo do usuário passam por `path.basename()` + allowlist
- [ ] Race conditions críticas usam transação + lock pessimista ou idempotency key
- [ ] JWT valida `alg` esperado explicitamente — rejeita `alg: none` e `HS256` se você usa RS256
- [ ] Tokens (reset password, magic link) são single-use, expiram em < 15 min, gerados com CSPRNG
- [ ] Comparação de strings sensíveis usa `crypto.timingSafeEqual`
- [ ] Logs registram tentativas de acesso negadas com IP/user-agent
- [ ] Deserialização confiável: nada de `pickle.loads`, `unserialize()` em input não-confiável

### Sênior (S)
- [ ] SAST (Semgrep, CodeQL, SonarQube) rodando em todo PR com gates configurados
- [ ] Regras customizadas de SAST para padrões internos (ex: "todo controller deve estender BaseAuth")
- [ ] Fuzz testing (libFuzzer, Atheris) em parsers e funções críticas
- [ ] Threat modeling escrito (STRIDE) para cada domínio crítico
- [ ] Code review obrigatório com checklist de segurança em features sensíveis
- [ ] Privacy by design: PII só é coletada quando essencial, com data minimization
- [ ] Anti-fraude: rate limit por usuário, device fingerprint, behavior analysis
- [ ] Audit log de ações sensíveis com correlation ID, immutable storage
- [ ] Bug bounty interno ou plataforma pública (HackerOne, BugCrowd)

## Comandos & ferramentas

```bash
# Semgrep — SAST com regras prontas
semgrep --config=p/owasp-top-ten --config=p/security-audit

# CodeQL · Bandit · gosec · OWASP ZAP
codeql database analyze db --format=sarif-latest
bandit -r src/ -ll
gosec ./...
zap-cli quick-scan https://staging.app.com
```

## BOLA — antes & depois

### Antes (vulnerável)
```javascript
// GET /api/orders/:id — qualquer user vê qualquer order
app.get('/api/orders/:id', async (req, res) => {
  const order = await Order.findById(req.params.id);
  res.json(order);  // 🚨 BOLA
});
```

### Depois (ownership check)
```javascript
app.get('/api/orders/:id', requireAuth, async (req, res) => {
  const order = await Order.findOne({
    _id: req.params.id,
    userId: req.user.id  // scope forçado
  });
  if (!order) return res.status(404).end();
  res.json(order);
});
```

## SSRF mitigation

```javascript
async function isPublicHost(url) {
  const { hostname } = new URL(url);
  const ip = await dns.lookup(hostname);
  return !ip.address.match(
    /^(127\.|10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|169\.254\.)/
  );
}
```

## Mass assignment fix (Zod)

```javascript
const UpdateUserSchema = z.object({
  name: z.string().min(2).max(100),
  email: z.string().email(),
  // role e isAdmin propositalmente fora do schema
}).strict(); // rejeita campos extras

app.patch('/users/me', requireAuth, async (req, res) => {
  const data = UpdateUserSchema.parse(req.body);
  await User.update(req.user.id, data);
});
```

## Sinais de equipe imatura

- "A gente confia que o frontend não vai mandar isso" — atacante não usa o frontend
- "SQL injection já tá resolvido com ORM" — ainda dá pra fazer com raw queries
- "Esse endpoint é interno, não precisa autorizar" — todo endpoint vira público em algum momento
- "Hash MD5 é mais rápido" — e por isso é mais fácil de quebrar com GPU
- "A gente loga tudo, qualquer auditoria a gente acha" — incluindo o token do usuário

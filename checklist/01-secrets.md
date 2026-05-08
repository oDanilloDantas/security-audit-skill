# Camada 01 · Secrets & Credenciais

> **O que esta camada cobre:** API keys, tokens JWT, senhas de banco, certificados, chaves SSH, credenciais SMTP. Vazamento de secret é vetor #1 em data breaches públicos.

## Checklist completo (28 itens)

### Básico (B) — mínimo aceitável

- [ ] `.env` está no `.gitignore` e nunca foi commitado em nenhum branch
- [ ] Histórico completo do Git foi escaneado com `gitleaks` ou `trufflehog`, não só HEAD
- [ ] Pre-commit hook (`husky + gitleaks`) bloqueia commit que contenha secret
- [ ] Secrets diferentes entre `dev`, `staging` e `prod` — sem reaproveitamento
- [ ] JWT signing secret tem 256 bits ou mais e é gerado com CSPRNG
- [ ] Senhas de banco e API keys estão em variáveis de ambiente do runtime, não em arquivos versionados

### Médio (M) — padrão de mercado

- [ ] Secrets em produção vivem num secret manager (AWS Secrets Manager, GCP Secret Manager, HashiCorp Vault, Doppler)
- [ ] AWS keys têm rotação automatizada via Secrets Manager rotation Lambda
- [ ] Logs estruturados removem campos sensíveis automaticamente (Pino redact, Winston format)
- [ ] Sentry/Datadog tem PII scrubbing configurado e testado com payload conhecido
- [ ] URLs em logs nunca contêm tokens em query string (todos via header `Authorization`)
- [ ] Headers `Authorization`, `Cookie`, `X-API-Key` estão na lista de redação dos logs
- [ ] CI/CD nunca printa `env` em job logs
- [ ] Banco e Redis usam senhas únicas; sem credencial padrão (`postgres/postgres`)
- [ ] Existe inventário escrito de todas as credenciais em uso, com responsável e data da última rotação
- [ ] SSH keys de produção são por pessoa, jamais compartilhadas
- [ ] Acesso a secrets é auditado: log de quem leu o quê e quando (CloudTrail, Vault audit log)

### Sênior (S) — maturidade avançada

- [ ] Rotação automática mensal de secrets críticos com testes de fallback
- [ ] Curto-circuito: se um secret foi exposto em log, alarme em < 5 minutos via SIEM
- [ ] Chaves criptográficas críticas vivem em KMS/HSM, não em arquivos no disco
- [ ] Política de "no plaintext at rest" — disco e backup criptografados via KMS gerenciado
- [ ] Web hooks externos usam HMAC com signing secret rotacionado
- [ ] Dynamic secrets (Vault) ao invés de credenciais estáticas para banco onde possível
- [ ] Princípio do menor privilégio: cada secret só pode o que precisa, escopo testado periodicamente
- [ ] Plano de incidente de vazamento de secret: detectar, revogar, rotacionar, comunicar — em runbook escrito
- [ ] "Break glass" credentials separadas, em cofre físico/digital fora do sistema, para uso emergencial auditado
- [ ] Honey tokens espalhados pelo código — credencial falsa que dispara alerta se usada
- [ ] SBOM e secret inventory revisados trimestralmente em comitê de segurança

## Comandos & ferramentas

```bash
# Escaneia o histórico inteiro do repo, todos os branches
gitleaks detect --source . --verbose --redact

# TruffleHog — só vulnerabilidades verificáveis
trufflehog filesystem . --only-verified

# AWS keys no histórico
git log --all -S "AKIA" --oneline

# Pre-commit hook
brew install gitleaks && gitleaks install hooks
```

## Como detectar (regex úteis)

| Tipo | Padrão |
|------|--------|
| AWS access key | `AKIA[0-9A-Z]{16}` |
| AWS secret | `[A-Za-z0-9/+=]{40}` (em contexto AWS) |
| GitHub PAT | `ghp_[a-zA-Z0-9]{36}` |
| Stripe live key | `sk_live_[0-9a-zA-Z]{24}` |
| Slack token | `xox[baprs]-[0-9a-zA-Z]+` |
| Generic JWT | `eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}` |
| Private key | `-----BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY-----` |

## Sinais de equipe imatura (red flags)

- "A gente já trocou todas as keys uma vez" — rotação é processo, não evento
- "Nosso secret manager é o .env mesmo" — falha grave de classificação
- "Só os devs sêniores têm acesso aos secrets" — princípio do menor privilégio violado
- "Não dá pra rotacionar agora, ia quebrar tudo" — secret virou single point of failure
- "A gente removeu o secret do código em 2022" — mas e o histórico do Git?

## Como corrigir

### Antes — secret hardcoded
```javascript
module.exports = {
  database: "postgres://admin:S3nh4@db.prod/app",
  stripe_key: "sk_live_51HxK...",
  jwt_secret: "meu-segredo-123"
};
```

### Depois — env var + validação no boot
```javascript
const required = ['DATABASE_URL', 'STRIPE_KEY', 'JWT_SECRET'];
required.forEach(k => {
  if (!process.env[k]) throw new Error(`missing ${k}`);
});
module.exports = {
  database: process.env.DATABASE_URL,
  stripeKey: process.env.STRIPE_KEY,
  jwtSecret: process.env.JWT_SECRET
};
```

### Logs com PII redaction (Pino)
```javascript
const logger = pino({
  redact: {
    paths: ['req.headers.authorization', 'req.headers.cookie',
            '*.password', '*.cardNumber', '*.cpf'],
    censor: '[REDACTED]'
  }
});
```

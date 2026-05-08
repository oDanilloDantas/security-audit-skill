# Camada 08 · CI/CD & Supply Chain Interna

> **O que esta camada cobre:** GitHub Actions, GitLab CI, branch protection, secrets do CI, signed commits, SLSA provenance.

## Checklist completo (26 itens)

### Básico (B)
- [ ] Branch protection no main: PR obrigatório, review, status checks
- [ ] Force-push e branch deletion bloqueados em branches de produção
- [ ] Signed commits obrigatórios no main (GPG ou SSH signing)
- [ ] Secrets do CI/CD em vault gerenciado, jamais em repo
- [ ] Workflows não fazem `echo` de secrets em logs
- [ ] CODEOWNERS configurado em paths sensíveis

### Médio (M)
- [ ] Workflows pin'am actions por SHA, não por tag (`@v4` é mutável)
- [ ] `pull_request_target` usado com cuidado extremo, sem checkout do PR sem revisão
- [ ] GITHUB_TOKEN com permissão **read** por padrão, write apenas onde necessário
- [ ] Secrets segregados por ambiente (dev/staging/prod), não compartilhados
- [ ] Required environments com aprovação manual antes de deploy em produção
- [ ] Self-hosted runners isolados em rede própria, ephemeral por job
- [ ] Build artifacts assinados com cosign, deploy só aceita assinados
- [ ] Dependabot/Renovate configurado pra actions também (não só deps de código)
- [ ] Secret scanning ativo no repo (push protection ligado)
- [ ] Workflows aprovados explicitamente para forks; padrão é "require approval"
- [ ] Audit log do GitHub/GitLab exportado pro SIEM
- [ ] Deploy keys / PATs revogados após uso ou rotacionados periodicamente

### Sênior (S)
- [ ] SLSA Level 2+ no pipeline: provenance gerada e verificada
- [ ] Sigstore + Rekor para transparency log de artefatos
- [ ] Hermetic builds: sem network, dependências resolvidas antecipadamente
- [ ] Reproducible builds — mesmo input gera mesmo binário
- [ ] Two-person review obrigatório para mudanças em workflows e infra crítica
- [ ] OIDC entre GitHub Actions e cloud — sem long-lived secrets em CI
- [ ] Tampering detection: alarme se workflow YAML for modificado sem aprovação
- [ ] Tabletop exercise anual de "comprometimento de pipeline": como detectar e responder

## Comandos & ferramentas

```bash
# Audita workflows · Lista PATs ativos
gh-actions-audit --org minha-empresa
gh api /user/tokens

# Action mutável (RUIM): actions/checkout@v4
# Pin por SHA (BOM):
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11

# Verifica provenance SLSA
slsa-verifier verify-artifact --provenance-path provenance.json \
  --source-uri github.com/empresa/app artifact.tar.gz
```

## Workflow seguro — antes & depois

### Antes (vulnerável a PR injection)
```yaml
on: pull_request_target  # tem secrets!
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - run: npm install && npm test  # roda código do PR
```

### Depois (jobs separados, action pinada por SHA)
```yaml
on: pull_request  # sem secrets pro fork
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be...
      - run: npm ci --ignore-scripts && npm test
```

## OIDC para deploy AWS (sem secrets)

```yaml
jobs:
  deploy:
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123:role/github-deploy
          aws-region: us-east-1
      # Sem AWS_ACCESS_KEY_ID, sem AWS_SECRET_ACCESS_KEY
```

## Sinais de equipe imatura

- "Usamos @latest ou @v4 nas actions" — tag é mutável, atacante pode trocar
- "CI roda código do PR direto, é mais conveniente" — porta aberta pra fork malicioso
- "Tem um PAT genérico que todo mundo usa" — owner desse PAT é o quê?
- "Self-hosted runner roda no laptop do dev" — você confia tudo no laptop?
- "Deploy é manual mesmo" — sem auditoria, sem rastro, sem rollback automatizado

# Camada 02 · Dependências & Supply Chain

> **O que esta camada cobre:** pacotes de terceiros (npm, pip, gems, etc.), CVEs, typosquatting, dependency confusion, supply chain comprometido.

## Checklist completo (27 itens)

### Básico (B)
- [ ] `npm audit` / `pip-audit` / `go vet` roda em todo CI; build falha em high/critical
- [ ] Lockfile (`package-lock.json`, `poetry.lock`, `go.sum`) está commitado e é fonte da verdade
- [ ] `npm install` em CI usa `npm ci` com lockfile imutável, não `npm i`
- [ ] Dependabot/Renovate habilitado para PRs automáticos de bump
- [ ] Pacotes deprecated foram identificados e plano de migração existe
- [ ] Dependências de dev (testes, lint) separadas de runtime — não vão pro container final

### Médio (M)
- [ ] Snyk, GitHub Advanced Security ou Socket.dev rodando em todo PR, com bloqueio
- [ ] Política de "no install scripts" para pacotes não auditados (`--ignore-scripts`)
- [ ] Allowlist de licenças configurada — bloqueia GPL, AGPL e desconhecidas se você é SaaS proprietário
- [ ] Verificação anti-typosquatting: `npm-name-validator` ou similar antes de adicionar dep
- [ ] Pacotes internos publicados em registry privado (Verdaccio, Artifactory, GitHub Packages)
- [ ] Scope NPM com `@empresa/` registrado para impedir dependency confusion
- [ ] Política contra "latest" — versões pinadas com `~` ou `^` conscientes
- [ ] Container base image atualizada nos últimos 30 dias — Alpine/Distroless preferidos
- [ ] Trivy ou Grype escaneia containers no build, com gate de critical=0
- [ ] Política de descontinuação: dep sem update em 18 meses entra em revisão obrigatória
- [ ] Forks internos de libs críticas mantidos, com plano de tomar manutenção se upstream cair

### Sênior (S)
- [ ] SBOM gerado em todo build (CycloneDX ou SPDX) e armazenado por >1 ano
- [ ] SBOM publicado junto com release (atestado de procedência verificável)
- [ ] Sigstore/cosign verificando assinaturas de pacotes e imagens base
- [ ] Scorecard (OSSF) rodando contra dependências críticas — score mínimo definido
- [ ] Política para "package age": pacotes < 90 dias são auditados manualmente
- [ ] SLSA Level 2+ no pipeline de build dos pacotes críticos
- [ ] Análise estática de dependências transitivas, não só diretas
- [ ] Honey package interno publicado pra detectar tentativas de dependency confusion
- [ ] Runbook escrito de "supply chain incident" (com exemplos de event-stream, ua-parser-js)
- [ ] Comitê trimestral revisa top-10 deps por blast radius

## Comandos & ferramentas

```bash
# Audit de dependências (Node)
npm audit --audit-level=high
npm audit fix --force  # cuidado: pode quebrar API

# Snyk — análise profunda + transitivas
snyk test --severity-threshold=high
snyk monitor

# Container scanning
trivy image minha-app:latest --severity CRITICAL,HIGH
grype minha-app:latest

# SBOM (CycloneDX)
cyclonedx-npm --output-file sbom.json

# Verificar assinatura (cosign)
cosign verify --key cosign.pub minha-app:latest
```

## Anti-typosquatting na prática

```json
// package.json — scope para deps internos
{
  "name": "@empresa/api-client",
  "publishConfig": { "registry": "https://npm.empresa.com" }
}
```

```bash
# Bloqueia install scripts em CI
npm ci --ignore-scripts
```

## Detectando supply chain comprometido

- Mudança recente de mantenedor; install script novo numa minor version
- Spike anômalo de tamanho do pacote sem changelog correspondente
- Network call em pacote que historicamente não fazia
- Repo arquivado / sem atividade nos últimos 6 meses

## Sinais de equipe imatura

- "A gente roda npm audit, tá tudo OK" — você só vê 30% do risco real
- "Nosso lockfile não tá no Git porque dá conflito" — você não tem builds reprodutíveis
- "Esse pacote não tem CVE" — CVE é evento, comprometimento é processo
- "A gente confia no mantenedor" — confiança não é controle
- "Atualizar quebra a build" — débito técnico virando débito de segurança

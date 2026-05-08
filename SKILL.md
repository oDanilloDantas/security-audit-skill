---
name: security-audit
description: Use this skill whenever the user wants to audit a codebase for security vulnerabilities across the 9 layers framework (secrets, dependencies, code, web security, auth, database, cloud/infra, CI/CD, compliance). Triggers on commands like `/security-audit`, requests like "auditar segurança do meu código", "scan vulnerabilities", "check security", "rode auditoria", or any request to evaluate security posture of a project. Produces a prioritized markdown report mapped to the 9 camadas methodology.
---

# Security Audit · 9 Camadas

Esta skill executa uma auditoria de segurança em camadas no código atual, gera relatório priorizado e indica próximos passos. Cobertura honesta: ~30% dos 240+ checks da metodologia completa — o resto exige revisão humana, threat modeling ou pentest.

## Quando esta skill é acionada

- Usuário roda `/security-audit` ou similar
- Usuário pede "auditar segurança", "scan de vulnerabilidades", "checar secrets"
- Usuário menciona "compliance", "LGPD", "OWASP" no contexto do código aberto
- Usuário quer revisão pré-deploy ou pré-merge de PR

## Princípios

1. **Nunca finja autoridade que não tem.** Esta skill detecta o óbvio. Findings críticos exigem confirmação humana antes de virar tarefa.
2. **Priorize por blast radius.** Critical bloqueia merge. High vai pra próxima sprint. Medium/Low entram em hardening.
3. **Falsos positivos existem.** Sempre cite o arquivo + linha pra usuário verificar. Se não tem certeza, marca como `needs-review`.
4. **Não execute scan destrutivo.** Sem network calls a serviços terceiros, sem mudança em arquivos do usuário, sem upload de código.
5. **Output em Markdown.** Sempre salva em `.security/audit-{YYYY-MM-DD}.md` no projeto auditado.

## Fluxo de execução

Quando acionada, siga este fluxo:

### 1. Detectar contexto do projeto

Antes de qualquer coisa, identifique:

- **Linguagem principal:** procure por `package.json` (Node), `pyproject.toml`/`requirements.txt` (Python), `go.mod` (Go), `Gemfile` (Ruby), `pom.xml`/`build.gradle` (Java)
- **Framework:** Express, Next.js, FastAPI, Django, Rails, etc.
- **Cloud provider:** procure por `terraform/`, `cloudformation/`, `.aws/`, `serverless.yml`
- **Container:** `Dockerfile`, `docker-compose.yml`, `k8s/`
- **CI/CD:** `.github/workflows/`, `.gitlab-ci.yml`, `circle.yml`

Use isso pra decidir quais scripts rodar. Não rode todos cegamente.

### 2. Verificar ferramentas instaladas

Antes de cada scan, verifique se a tool existe (`command -v gitleaks`, etc.). Se não existe, instrua o usuário:

```
gitleaks não está instalado. Para instalar:
  brew install gitleaks         # macOS
  apt install gitleaks          # Debian/Ubuntu
  ou rode: ./scripts/setup.sh
```

### 3. Executar camadas relevantes

Rode em ordem (mais barato primeiro, mais caro depois):

1. **`scan-secrets.sh`** — sempre roda (gitleaks no histórico inteiro)
2. **`scan-deps.sh`** — roda se detectou linguagem com package manager
3. **`scan-code.sh`** — roda se Semgrep está instalado (SAST)
4. **`scan-web.sh`** — roda se detectou Express/Next/etc rodando local
5. **`scan-db.sh`** — roda se detectou config de banco
6. **`scan-cloud.sh`** — roda se detectou IaC ou credenciais AWS configuradas
7. **`scan-cicd.sh`** — roda se há workflows GitHub Actions
8. **`scan-compliance.sh`** — roda checks documentais (existência de privacy policy, DPA, etc.)

### 4. Coletar findings de cada camada

Cada script retorna JSON estruturado:

```json
{
  "layer": "01-secrets",
  "findings": [
    {
      "severity": "critical",
      "title": "AWS access key in git history",
      "file": "config/aws.js",
      "line": 14,
      "rule": "gitleaks:aws-access-key",
      "fix": "Rotate the key in IAM, then run git filter-repo to clean history",
      "doc_ref": "Camada 1 · Secrets — guia pág. 4"
    }
  ]
}
```

### 5. Gerar relatório final

Use o template em `templates/report.md.tpl`. Substitua placeholders, ordene por severity (critical → high → medium → low), agrupe por camada.

Ao final, mostre um sumário no chat com:
- Total de findings por severity
- Top 3 issues críticas
- Caminho do relatório completo
- Próximos passos sugeridos

### 6. Quando NÃO continuar

- Se o repositório tem `.security/skip-audit` no root, abortar com aviso
- Se o usuário pediu skip de uma camada, respeitar
- Se uma ferramenta crítica está faltando e o usuário declinou instalar, registrar no relatório como "não escaneado"

## Estrutura de severity

- **Critical:** vulnerabilidade explorável agora ou exposição direta de PII/credenciais. Bloqueia merge.
- **High:** falha de hardening relevante. Resolve na próxima sprint. Documenta exceção temporária se postergar.
- **Medium:** desvio de boa prática sem impacto imediato. Próximo ciclo de hardening.
- **Low/Info:** melhoria contínua. Trata em batches.
- **Needs-review:** finding ambíguo que humano precisa avaliar (ex: regex pegou padrão que talvez seja secret, talvez não).

## Cobertura honesta por camada

| Camada | Cobertura desta skill |
|--------|----------------------|
| 01 · Secrets | ~50% |
| 02 · Dependências | ~48% |
| 03 · Código | ~27% |
| 04 · Web Security | ~46% |
| 05 · Auth & AuthZ | ~21% |
| 06 · Banco de Dados | ~28% |
| 07 · Cloud & Infra | ~32% |
| 08 · CI/CD | ~31% |
| 09 · Compliance | ~7% |

Os outros 70% precisam de revisão humana, threat modeling, pentest profissional ou auditoria de compliance.

## Limitações conhecidas

- **Não testa runtime.** Race conditions, IDOR contextual, lógica de negócio escapam.
- **Falsos positivos.** Sempre confirme antes de marcar como crítico.
- **Bias por ecossistema.** Funciona melhor em Node/Python/Go. Ecossistemas menores têm menos regras.
- **Compliance fica fora.** Auditoria LGPD/SOC2 exige documentação humana além do que dá pra automatizar.
- **Sem network calls.** Não scaneamos endpoints HTTP em produção (DAST exige autorização explícita).

## Referências

- Documento completo das 9 camadas: ver `Guia-Auditoria-de-Seguranca-em-9-Camadas-por-Danillo-Dantas.pdf`
- Carrossel introdutório: https://www.instagram.com/p/DYD1zh1keHL
- Consultoria sênior: https://instagram.com/danillodantas.ia

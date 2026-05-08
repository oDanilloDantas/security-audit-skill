# Security Audit Skill · 9 Camadas

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Methodology](https://img.shields.io/badge/methodology-9_camadas-F97316.svg)](#metodologia)

> **Auditoria de segurança em 9 camadas**, executada via [Claude Code](https://docs.claude.com/en/docs/claude-code/overview). Da skill automatizada ao pentest profissional.

Esta skill é uma referência operacional pra equipes brasileiras que querem auditar código sem reinventar a roda. Cobre ~30% dos 240+ checks da metodologia completa — o resto exige humano.

## Instalação rápida

```bash
# 1. Clone num local que o Claude Code reconheça como skills folder
git clone https://github.com/danillodantas/security-audit-skill ~/.claude/skills/security-audit

# 2. Instale ferramentas externas (gitleaks, trivy, semgrep, etc.)
cd ~/.claude/skills/security-audit
./scripts/setup.sh

# 3. Use no seu projeto
cd /path/to/your-project
claude
> /security-audit
```

## Uso direto via shell (sem Claude)

Você também pode rodar os scripts standalone, sem Claude:

```bash
# Auditoria completa
~/.claude/skills/security-audit/scripts/audit.sh

# Só uma camada
~/.claude/skills/security-audit/scripts/audit.sh --layer=01

# Em CI — falha se houver crítico
~/.claude/skills/security-audit/scripts/audit.sh --gate=critical

# Pula camadas específicas
~/.claude/skills/security-audit/scripts/audit.sh --skip=07,08
```

O relatório vai pra `.security/audit-YYYY-MM-DD.md` no projeto auditado.

## Metodologia

Esta skill implementa o framework de 9 camadas:

| # | Camada | Cobertura desta skill |
|---|--------|----------------------|
| 01 | **Secrets & Credenciais** | ~50% |
| 02 | **Dependências & Supply Chain** | ~48% |
| 03 | **Código & Lógica** | ~27% |
| 04 | **Web Security & Headers** | ~46% |
| 05 | **Auth & AuthZ** | ~21% |
| 06 | **Banco de Dados & PII** | ~28% |
| 07 | **Cloud & Infraestrutura** | ~32% |
| 08 | **CI/CD & Supply Chain Interna** | ~31% |
| 09 | **Compliance & LGPD** | ~7% |

Total: **~30%** dos 240+ checks. O resto precisa de revisão humana.

## Estrutura

```
security-audit-skill/
├── SKILL.md              # Instruções pro Claude
├── README.md             # Este arquivo
├── checklist/            # Markdown reference por camada
│   ├── 01-secrets.md
│   ├── 02-dependencies.md
│   ├── 03-code.md
│   ├── 04-web-security.md
│   ├── 05-auth.md
│   ├── 06-database.md
│   ├── 07-cloud.md
│   ├── 08-cicd.md
│   └── 09-compliance.md
├── scripts/              # Scan scripts shell
│   ├── _common.sh        # Helpers compartilhados
│   ├── setup.sh          # Instala ferramentas externas
│   ├── audit.sh          # Orquestrador principal
│   ├── scan-secrets.sh
│   ├── scan-deps.sh
│   ├── scan-code.sh
│   ├── scan-web.sh
│   ├── scan-auth.sh
│   ├── scan-db.sh
│   ├── scan-cloud.sh
│   ├── scan-cicd.sh
│   ├── scan-compliance.sh
│   └── render-report.sh
├── templates/
│   └── report.md.tpl     # Template do relatório
└── .github/workflows/
    └── security-audit.yml # Action de exemplo
```

## Ferramentas externas usadas

| Tool | Camada | Por quê |
|------|--------|---------|
| [gitleaks](https://github.com/gitleaks/gitleaks) | 01 | Secrets em histórico Git |
| [trufflehog](https://github.com/trufflesecurity/trufflehog) | 01 | Secrets verificáveis |
| [Snyk](https://snyk.io/) ou `npm audit` | 02 | CVEs em dependências |
| [Trivy](https://github.com/aquasecurity/trivy) | 02, 07 | Containers + IaC |
| [Semgrep](https://semgrep.dev/) | 03 | SAST com regras OWASP |
| [Bandit](https://github.com/PyCQA/bandit) | 03 | SAST Python |
| [gosec](https://github.com/securego/gosec) | 03 | SAST Go |
| [Tfsec](https://github.com/aquasecurity/tfsec) / [Checkov](https://github.com/bridgecrewio/checkov) | 07 | Terraform |
| [Prowler](https://github.com/prowler-cloud/prowler) | 07 | AWS CIS Benchmark |

Todas instaláveis via `./scripts/setup.sh`.

## Rodando em CI

Veja [.github/workflows/security-audit.yml](.github/workflows/security-audit.yml) para um exemplo completo. Versão mínima:

```yaml
name: Security Audit
on: pull_request
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11  # v4
      - run: |
          git clone https://github.com/danillodantas/security-audit-skill /tmp/sec
          /tmp/sec/scripts/setup.sh
          /tmp/sec/scripts/audit.sh --gate=critical
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: security-report
          path: .security/
```

## Limitações & honestidade

Esta skill **não substitui**:

- 🚫 **Pentest profissional** — vetor humano criativo
- 🚫 **Threat modeling** — discussão de arquitetura
- 🚫 **Auditoria de compliance** — LGPD/SOC2 exige documentação humana
- 🚫 **DAST em produção** — exige autorização explícita
- 🚫 **Runtime security** — agente em produção

Falsos positivos existem — sempre confirme antes de marcar como crítico.

## Material de referência

- 📘 [Guia completo das 9 Camadas](docs/Guia-Auditoria-de-Seguranca-em-9-Camadas-por-Danillo-Dantas.pdf) — checklist sênior em PDF (37 páginas, 240+ checks)
- 📱 [Carrossel introdutório](https://www.instagram.com/p/DYD1zh1keHL) — explicação visual rápida
- 🏢 [Consultoria sênior · SCALE Performance](https://instagram.com/danillodantas.ia) — auditoria humana das 9 camadas no contexto do seu negócio

## Licença

MIT. Use, fork, melhore. Se a skill te ajudou a evitar um incidente, me conta — eu compartilho cases (anonimizados) com a comunidade.

## Contribuindo

PRs bem-vindos. Áreas onde mais ajuda é necessária:

- Mais regras de Semgrep customizadas pra padrões brasileiros (CPF, CNPJ leak)
- Suporte a Ruby/PHP/Java SAST
- Template de relatório em SARIF (pra GitHub Security tab)
- Integração com SIEM (export pra Datadog, Splunk)

Antes de PR, rode `./scripts/audit.sh` no próprio repo &mdash; meta-auditoria. 🙃

---

**Mantido por** [@danillodantas.ia](https://instagram.com/danillodantas.ia) · SCALE Performance

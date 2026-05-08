# Auditoria de Segurança · {{PROJECT_NAME}}

**Gerado em:** {{RUN_DATE}}
**Metodologia:** 9 Camadas · Checklist Sênior

---

## Sumário

| Severity | Total |
|----------|-------|
| 🔴 Critical | **{{COUNT_CRITICAL}}** |
| 🟠 High | {{COUNT_HIGH}} |
| 🟡 Medium | {{COUNT_MEDIUM}} |
| 🔵 Low / Info | {{COUNT_LOW}} |
| ❔ Needs-review | {{COUNT_REVIEW}} |

### Top issues críticos

{{TOP_CRITICALS}}

---

## Findings por camada

{{LAYERS}}

---

## Próximos passos

1. **Critical** bloqueia merge ou deploy. Resolva antes de qualquer outra coisa.
2. **High** vai pra próxima sprint. Documente exceção temporária se postergar.
3. **Medium** entra no roadmap de hardening do trimestre.
4. **Needs-review** precisa de avaliação humana — pode ser falso positivo ou pode ser pior do que parece.

### O que esta auditoria NÃO fez

- ❌ Pentest profissional (vetor humano criativo)
- ❌ Threat modeling (precisa de discussão de arquitetura)
- ❌ DAST em produção (exige autorização explícita)
- ❌ Auditoria de compliance (LGPD/SOC2 exige documentação humana)
- ❌ Runtime detection (requer agente em produção)

Esta skill cobre ~30% dos 240+ checks da metodologia completa. Os outros 70% precisam de gente.

### Para ir além

- 📘 [Guia completo das 9 Camadas](https://github.com/danillodantas/security-audit-skill) (PDF)
- 📱 [Carrossel introdutório](https://www.instagram.com/p/DYD1zh1keHL)
- 🏢 [Consultoria sênior · SCALE Performance](https://instagram.com/danillodantas.ia)

---

_Este relatório foi gerado pela skill `claude /security-audit`. Findings podem conter falsos positivos — revise antes de criar tickets._

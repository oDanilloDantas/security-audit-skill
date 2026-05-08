# Camada 09 · Compliance & LGPD

> **O que esta camada cobre:** LGPD, GDPR, PCI-DSS, ISO 27001, SOC 2 — conformidade regulatória traduzida em controles técnicos.

## Checklist completo (27 itens)

### Básico (B)
- [ ] Inventário de dados pessoais tratados (registro das operações de tratamento, art. 37 LGPD)
- [ ] Base legal definida para cada tratamento (consentimento, execução de contrato, legítimo interesse, etc)
- [ ] Política de Privacidade publicada, em linguagem acessível, atualizada
- [ ] Termo de Uso separado da Política de Privacidade
- [ ] Cookie banner com opt-in granular para cookies não-essenciais
- [ ] Canal de contato pra titular exercer direitos (e-mail dedicado, formulário)
- [ ] DPO (Encarregado) designado e divulgado se há tratamento sistemático

### Médio (M)
- [ ] 8 direitos do titular implementados tecnicamente — ver Apêndice D do guia
- [ ] DPIA (RIPD) elaborada para tratamentos de alto risco
- [ ] DPA (acordo de tratamento) com todo fornecedor SaaS que processa dados pessoais
- [ ] Sub-operadores listados publicamente
- [ ] Transferência internacional com cláusulas contratuais ou país com nível adequado
- [ ] Retention policy automatizada — dados deletados conforme art. 16 LGPD
- [ ] Anonymization/pseudonymization aplicada onde possível
- [ ] Breach response plan: comunicação à ANPD em < 72h e aos titulares afetados
- [ ] Minor consent: tratamento de dados de criança/adolescente com consentimento dos pais
- [ ] Privacy by Design documentado em features novas
- [ ] Treinamento anual em LGPD para equipes de produto, dev e suporte

### Sênior (S)
- [ ] ISO 27001 (ou em processo de certificação) com SoA documentado
- [ ] SOC 2 Type II auditado anualmente — controles em CC, A, P, C, PI
- [ ] PCI-DSS aplicado se processa cartão direto, ou tokenização via PSP certificado
- [ ] NIST CSF (Cybersecurity Framework) usado como mapa de maturidade
- [ ] CIS Controls v8 implementadas e auditadas
- [ ] Trust Center público com SOC reports (sob NDA), DPA modelo, security overview
- [ ] Insurance: cyber liability + tech E&O dimensionada pela ARR
- [ ] Vendor risk management formal: questionário, score, revisão anual
- [ ] Ethical AI: viés, transparência e accountability documentados se usa IA com decisão automatizada

## Mapa de frameworks por tipo de negócio

### SaaS B2B brasileiro
- **Mínimo:** LGPD compliance + DPA pronta + cookie banner
- **Pra crescer:** SOC 2 Type II + ISO 27001
- **Enterprise:** + Trust Center público, cyber insurance

### E-commerce / Fintech
- **Obrigatório:** LGPD + PCI-DSS (ou tokenização via PSP) + Bacen Resolução 4.658 se for instituição financeira
- **Recomendado:** ISO 27001, controles de prevenção a fraude

### Healthtech
- **Crítico:** LGPD + dados sensíveis (art. 11) + ANS/CFM regras setoriais
- Se atende EUA: HIPAA. Se UE: GDPR + medical device regulation

### Vende para governo brasileiro
- **Geralmente exigido:** ISO 27001 + LGPD + comprovações específicas do edital
- Marco Civil + leis setoriais aplicáveis

## 8 direitos do titular (LGPD art. 18)

1. **Confirmação** de existência de tratamento
2. **Acesso** aos dados
3. **Correção** de dados incompletos, inexatos ou desatualizados
4. **Anonimização, bloqueio ou eliminação** de dados desnecessários ou tratados em desconformidade
5. **Portabilidade** dos dados
6. **Eliminação** dos dados tratados com consentimento
7. **Informação** sobre compartilhamento
8. **Revogação** do consentimento

## Sinais de equipe imatura

- "A gente tem termo de uso atualizado" — termo ≠ política de privacidade
- "DPO é o sócio mesmo" — conflito de interesse, não tem independência
- "Cookie banner aceita por padrão" — opt-in é a regra, não opt-out
- "Vamos fazer LGPD depois do product-market fit" — multa não vai esperar PMF
- "Compliance é problema do jurídico" — todo controle é técnico antes de ser jurídico

# Camada 06 · Banco de Dados & PII

> **O que esta camada cobre:** banco de dados (SQL e NoSQL), criptografia em repouso e em trânsito, RLS para multitenant, mascaramento de PII, backup testado.

## Checklist completo (25 itens)

### Básico (B)
- [ ] Conexão ao banco usa TLS sempre, com cert validation
- [ ] Usuário do banco da app não é root/postgres — tem permissão mínima necessária
- [ ] Sem credenciais default em nenhum banco (Mongo, Redis, Postgres, MySQL)
- [ ] Banco não está exposto na internet pública — security group / firewall fechado
- [ ] Backup automatizado, frequência condizente com RPO definido
- [ ] Encryption at rest habilitado (AWS RDS encryption, transparent data encryption)

### Médio (M)
- [ ] Backup já foi testado com restore real em ambiente isolado nos últimos 90 dias
- [ ] RTO e RPO documentados, testados via tabletop exercise
- [ ] NoSQL injection prevenido — drivers parametrizados, validação de tipo no query builder
- [ ] Row Level Security (RLS) ativa em multitenant SaaS, com testes automatizados
- [ ] Column-level encryption em CPF, cartão, dados médicos (pgcrypto, AWS KMS)
- [ ] Tokenização ou format-preserving encryption para PCI scope
- [ ] Audit log de queries em tabelas sensíveis (pg_audit, MySQL audit plugin)
- [ ] Connection pool limita conexões; statement_timeout previne queries pesadas
- [ ] Read replica usada por workloads de leitura, isolando produção transacional
- [ ] Snapshots de backup armazenados em conta/região separada (cross-account)
- [ ] Migrations versionadas, com rollback testado, jamais aplicadas manualmente em prod

### Sênior (S)
- [ ] RLS testada com fuzz: ataques cross-tenant impossíveis por design
- [ ] Data masking automático em ambientes não-prod (Bytebase, Aiven)
- [ ] DLP monitora exfiltração: query que retorna > X linhas em < Y segundos alarma
- [ ] Immutable / WORM backup pra ransomware (S3 Object Lock, Veeam)
- [ ] Honey table — tabela com PII falsa que dispara alerta se for lida
- [ ] Data classification: cada coluna tem tag (public/internal/confidential/PII/PCI)
- [ ] Retention policy automatizada: dados expiram conforme LGPD art. 16
- [ ] Database firewall (jSonar, IBM Guardium) bloqueia query patterns suspeitos

## Comandos & ferramentas

```bash
# Postgres — checa conexões SSL ativas
psql -c "SELECT ssl, version, client_addr FROM pg_stat_ssl JOIN pg_stat_activity USING(pid);"

# Encontra colunas com PII potencial
psql -c "SELECT table_name, column_name FROM information_schema.columns WHERE column_name ~* '(cpf|card|email|phone|ssn)';"

# Teste RLS — entra como tenant A, tenta ler tenant B
psql -c "SET app.tenant_id = 'tenant_a'; SELECT * FROM orders WHERE tenant_id = 'tenant_b';"

# Backup test — restaura em instância isolada
pg_restore -d test_restore backup.dump
psql test_restore -c "SELECT count(*) FROM users;"
```

## Row Level Security (Postgres)

```sql
-- Multi-tenant: cada query enxerga só o próprio tenant
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON orders
  USING (tenant_id = current_setting('app.tenant_id')::uuid);

-- Em cada conexão, app seta o tenant atual
SET app.tenant_id = 'a4e8c1...';
```

## Column-level encryption

```sql
CREATE EXTENSION pgcrypto;

INSERT INTO users (id, cpf_encrypted) VALUES (
  uuid_generate_v4(),
  pgp_sym_encrypt('12345678900', current_setting('app.encryption_key'))
);

-- Lê descriptografado (só com a chave do KMS)
SELECT id, pgp_sym_decrypt(cpf_encrypted, ...) FROM users;
```

## Backup test runbook

1. Pega o backup mais recente do storage cross-account
2. Restaura em instância staging vazia (timer começa)
3. Roda smoke tests e compara checksums de tabelas-chave
4. Documenta tempo total + qualquer anomalia. RTO real registrado

## Sinais de equipe imatura

- "A gente faz backup todo dia" — quando foi a última vez que testou o restore?
- "Encryption at rest tá ON na AWS" — e a chave KMS, quem controla?
- "SQL injection? Usamos ORM" — raw queries continuam aceitando string concat
- "RLS é overhead" — multitenant sem RLS é tenant leak esperando acontecer
- "CPF está em texto plano, mas o banco é privado" — privado até alguém vazar credencial

# Camada 07 · Cloud & Infraestrutura

> **O que esta camada cobre:** configuração de cloud (AWS, GCP, Azure), IAM, S3 buckets, containers, Kubernetes, IaC (Terraform).

## Checklist completo (28 itens)

### Básico (B)
- [ ] Nenhum bucket S3/GCS público sem motivo documentado e assinado
- [ ] Block Public Access habilitado por padrão na conta AWS
- [ ] Conta root da AWS com MFA, sem access keys ativas, alerta em qualquer login
- [ ] CloudTrail habilitado em todas as regiões, logs em conta separada (audit account)
- [ ] Security Groups sem 0.0.0.0/0 em portas administrativas (22, 3389, 5432, etc)
- [ ] VPC privada para recursos internos; bastion host ou SSM Session Manager para SSH
- [ ] Imagens base atualizadas (Alpine 3.18+, Distroless, Wolfi)

### Médio (M)
- [ ] IAM com least privilege real — sem `Action: *` em produção
- [ ] IAM Access Analyzer habilitado, findings revisados semanalmente
- [ ] Roles assumidas via IRSA (EKS) ou Workload Identity (GKE), sem credentials estáticas em pods
- [ ] AWS Config / GCP Asset Inventory tracking drift de configuração
- [ ] Multi-account strategy: produção, staging, audit, security em contas separadas com SCP
- [ ] GuardDuty / Cloud Armor habilitado, alertas pra Slack/PagerDuty
- [ ] Terraform/IaC obrigatório para mudanças — sem clickops em prod
- [ ] Checkov, Tfsec ou tflint em todo PR de infra
- [ ] Containers não rodam como root (`USER 1000` no Dockerfile)
- [ ] Pod Security Standards configurado (restricted) no Kubernetes
- [ ] Network policies restringem tráfego pod-to-pod (Calico, Cilium)
- [ ] Service mesh (Istio, Linkerd) com mTLS entre serviços críticos
- [ ] Secrets em K8s usam external secret operator + Secrets Manager, não secrets nativos em texto

### Sênior (S)
- [ ] CSPM (Wiz, Prowler, Steampipe) rodando contra a conta inteira
- [ ] CIS Benchmark compliance score acompanhado mensalmente
- [ ] Runtime security (Falco, Sysdig Secure, Tetragon) detectando comportamento anômalo
- [ ] Image signing com cosign + admission controller validando assinatura no cluster
- [ ] Just-in-time access (Teleport, AWS Identity Center) — sem usuários permanentes
- [ ] Disaster recovery testado com chaos engineering (Chaos Monkey, AWS FIS)
- [ ] SCP (Service Control Policies) bloqueia regiões/serviços não usados
- [ ] Workload identity federation entre clouds — sem chaves cross-cloud

## Comandos & ferramentas

```bash
# Prowler — auditoria CIS Benchmark da AWS
prowler aws --severity high,critical

# Buckets S3 públicos
aws s3api list-buckets --query 'Buckets[].Name' --output text | \
  xargs -I{} aws s3api get-bucket-acl --bucket {}

# Tfsec / Checkov
tfsec .
checkov -d . --framework terraform

# Trivy num container
trivy image --scanners vuln,config,secret minha-app:v1
```

## IAM least privilege — antes & depois

### Antes (god mode)
```json
{ "Effect": "Allow", "Action": "*", "Resource": "*" }
```

### Depois (scoped)
```json
{
  "Effect": "Allow",
  "Action": ["s3:GetObject", "s3:PutObject"],
  "Resource": "arn:aws:s3:::uploads-prod/users/${aws:userid}/*",
  "Condition": { "Bool": { "aws:SecureTransport": "true" } }
}
```

## Dockerfile seguro

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM gcr.io/distroless/nodejs20-debian12
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=nonroot:nonroot . .
USER nonroot:nonroot      # UID 65532, sem shell
CMD ["server.js"]
```

## K8s Pod Security restricted

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

## Sinais de equipe imatura

- "A AWS é segura por padrão" — segurança compartilhada, lembra?
- "Tudo em uma conta só, mais simples" — explosion radius enorme
- "A gente faz mudança direto no console pra agilizar" — auditoria zero, drift garantido
- "Container roda como root, é só dev" — escape de container vira problema sério
- "Acesso permanente é mais prático" — JIT é o padrão moderno por uma razão

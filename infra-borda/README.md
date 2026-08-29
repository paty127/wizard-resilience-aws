# Infra de Borda — Case B (Wizard)

Terraform da camada de borda: **Route 53 + CloudFront + WAF + S3 (origens)**.

## O que está aqui

- `route53.tf` — Hosted Zone, Health Check e failover DNS (primário/secundário)
- `cloudfront.tf` — CDN com Origin Group (failover automático S3 primário → secundário) + OAC
- `waf.tf` — WAF WebACL com regras gerenciadas (Common, KnownBadInputs) + rate limiting por IP
- `acm.tf` — Certificado TLS com validação automática via DNS
- `s3.tf` — Buckets de origem (privados, acesso só via CloudFront)
- `variables.tf` / `terraform.tfvars.example` — configuração
- `outputs.tf` — valores úteis pros outros times (URL, IDs, bucket names)

**AWS Shield Standard** não aparece em nenhum arquivo porque é automático — já vem ativo em CloudFront e Route 53, sem custo, sem config.

## Como rodar

```bash
cp terraform.tfvars.example terraform.tfvars
# ajustar domain_name quando tivermos o domínio real

terraform init
terraform plan
terraform apply
```

**Atenção:** o `aws_route53_zone` cria uma hosted zone nova. Se formos usar
um domínio comprado fora da AWS, depois do `apply` é preciso pegar o output
`route53_nameservers` e configurar no registrador do domínio (ex: Registro.br).
Sem isso, a validação do ACM (DNS) e o failover não funcionam de verdade.

## Pendências / decisões em aberto

- [ ] **Domínio real**: hoje está com placeholder (`wizard-case-placeholder.com.br`) e
      `enable_custom_domain = false`. Nesse modo, o CloudFront usa o domínio padrão
      dele (`*.cloudfront.net`, com HTTPS já funcionando) — não tenta criar
      certificado ACM, porque a validação DNS nunca terminaria para um domínio
      fictício. **Quando tivermos o domínio real:**
      1. Trocar `domain_name` em `terraform.tfvars`
      2. Trocar `enable_custom_domain = true`
      3. Rodar `terraform apply`
      4. Pegar o output `route53_nameservers` e configurar no registrador do domínio
      5. Rodar `terraform apply` de novo (o ACM só valida depois que os nameservers propagarem)
- [ ] **Conteúdo do site**: os buckets `s3-primary` e `s3-secondary` estão vazios.
      Time de Backend/Storage faz o deploy do build estático neles (ver outputs
      `s3_bucket_primary` / `s3_bucket_secondary`).
- [ ] **Replicação S3 (CRR)**: não incluí Cross-Region Replication automática
      entre os buckets. Por enquanto, o deploy do site precisa subir pros dois
      buckets manualmente ou via pipeline CI/CD. Se quiserem CRR automática,
      é fácil adicionar — falem comigo.
- [ ] **Tags obrigatórias**: já aplicadas via `default_tags` no provider
      (`team`, `project`, `environment`) — cobre a exigência de governança.
- [ ] **Rate limit do WAF**: hoje em 2000 req/5min por IP, conforme o doc.
      Ajustável em `waf_rate_limit`.

## Para o time de Resiliência / Game Day

- `cloudfront_distribution_id` e `health_check_id` (nos outputs) são os IDs
  que vocês vão usar pra apontar o AWS FIS ou pra simular a queda manual
  (revogar o OAC do bucket primário via CLI, como alternativa de baixo custo).

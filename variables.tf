variable "primary_region" {
  description = "Região AWS primária"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Região AWS secundária (failover)"
  type        = string
  default     = "sa-east-1"
}

variable "domain_name" {
  description = "Domínio placeholder da campanha. Trocar pelo domínio real quando disponível."
  type        = string
  default     = "wizard-case-placeholder.com.br"
}

variable "subdomain" {
  description = "Subdomínio usado pela vitrine digital (ex: campanha.dominio.com.br)"
  type        = string
  default     = "campanha"
}

variable "project_tag" {
  description = "Tag obrigatória de projeto"
  type        = string
  default     = "case-b-resilience"
}

variable "team_tag" {
  description = "Tag obrigatória de equipe"
  type        = string
  default     = "bruma"
}

variable "environment" {
  description = "Tag obrigatória de ambiente"
  type        = string
  default     = "hackathon"
}

variable "waf_rate_limit" {
  description = "Limite de requisições por IP a cada 5 minutos (Rate-Based Rule do WAF)"
  type        = number
  default     = 2000
}

variable "short_url_bucket_name" {
  description = <<-EOT
    Nome do bucket S3 usado como "URL curta" memorizável para a demo ao vivo
    (redireciona via S3 website hosting pro domínio real do CloudFront).
    Precisa ser único globalmente entre todos os buckets S3 do mundo -
    se o apply falhar com BucketAlreadyExists, troque por outro nome.
  EOT
  type        = string
  default     = "wizard-bruma"
}

variable "enable_custom_domain" {
  description = <<-EOT
    Controla se o CloudFront usa domínio customizado + certificado ACM.
    Deixar como 'false' enquanto o domínio ainda for placeholder/fictício -
    a validação DNS do ACM nunca termina para um domínio que não existe de verdade.
    Trocar para 'true' assim que tivermos o domínio real e os nameservers
    apontando para a hosted zone criada aqui.
  EOT
  type        = bool
  default     = false
}

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

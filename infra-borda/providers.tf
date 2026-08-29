# Provider primário: us-east-1
# Obrigatório para: recursos globais (WAF WebACL para CloudFront, ACM para CloudFront)
provider "aws" {
  region = var.primary_region

  default_tags {
    tags = {
      team        = var.team_tag
      project      = var.project_tag
      environment  = var.environment
    }
  }
}

# Provider secundário: usado para o bucket S3 de origem replicada (failover)
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region

  default_tags {
    tags = {
      team        = var.team_tag
      project      = var.project_tag
      environment  = var.environment
    }
  }
}

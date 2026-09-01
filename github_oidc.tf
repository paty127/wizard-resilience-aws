# =============================================================================
# CI/CD da Landing Page - autenticacao do GitHub Actions via OIDC
#
# CONTEXTO PARA QUEM FOR APLICAR (Patricia / quem tiver o tfstate):
#
#   Estes dois recursos JA EXISTEM na conta. Foram criados a mao pelo console
#   em 31/08/2026 porque o tfstate e local e nao estava na maquina de quem
#   montou o pipeline. O codigo abaixo e a versao versionada dos mesmos
#   recursos, para que eles parem de ser infra "invisivel" e passem a viver
#   no IaC junto com o resto.
#
#   Para adotar sem recriar (senao o apply falha com EntityAlreadyExists),
#   rode os dois imports UMA VEZ antes do primeiro apply:
#
#     terraform import aws_iam_openid_connect_provider.github \
#       arn:aws:iam::140825045811:oidc-provider/token.actions.githubusercontent.com
#
#     terraform import aws_iam_role.lp_deploy bruma-lp-deploy
#
#   Depois disso, `terraform plan` deve sair limpo (ou com diferencas so de
#   tag, que o apply corrige). A partir dai o teardown.sh tambem passa a
#   limpar isso junto, sem deixar role orfa.
#
#   Se preferir NAO adotar: basta apagar os dois recursos no console
#   (IAM > Funcoes > bruma-lp-deploy e IAM > Provedores de identidade) e
#   deletar este arquivo. Nada mais na infra depende deles.
# =============================================================================

variable "github_owner" {
  description = "Owner do repositorio no GitHub"
  type        = string
  default     = "paty127"
}

variable "github_repo" {
  description = "Nome do repositorio no GitHub"
  type        = string
  default     = "wizard-resilience-aws"
}

variable "github_deploy_branch" {
  description = "Unica branch autorizada a assumir a role de deploy da LP"
  type        = string
  default     = "site-frontend"
}

# --- Provedor OIDC do GitHub ------------------------------------------------
# Permite que o GitHub Actions troque um token de identidade por credenciais
# temporarias da AWS. Elimina a necessidade de guardar access key no repo.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    component = "lp-deploy"
  }
}

# --- Confianca: SO a branch da LP -------------------------------------------
# A condicao no `sub` e o que impede o pipeline de rodar de qualquer outro
# lugar. Push na main, em outra branch ou em um fork nao consegue assumir
# esta role - a AWS recusa o AssumeRoleWithWebIdentity.
data "aws_iam_policy_document" "lp_deploy_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/${var.github_deploy_branch}"]
    }
  }
}

resource "aws_iam_role" "lp_deploy" {
  name        = "bruma-lp-deploy"
  description = "Deploy da LP (pasta lp/) via GitHub Actions OIDC. Restrito a branch site-frontend. Sem permissao de delete em S3."

  assume_role_policy = data.aws_iam_policy_document.lp_deploy_trust.json

  tags = {
    component = "lp-deploy"
  }
}

# --- Permissoes: minimo necessario, sem delete ------------------------------
# Deliberadamente SEM s3:DeleteObject. O pipeline consegue escrever e
# sobrescrever, nunca apagar. Combinado com o versionamento ligado nos dois
# buckets, qualquer publicacao e reversivel.
data "aws_iam_policy_document" "lp_deploy_permissions" {
  statement {
    sid    = "ListarApenasOsBucketsDeOrigem"
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]

    resources = [
      aws_s3_bucket.origin_primary.arn,
      aws_s3_bucket.origin_secondary.arn,
    ]
  }

  statement {
    sid    = "EscreverObjetosSemPoderApagar"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.origin_primary.arn}/*",
      "${aws_s3_bucket.origin_secondary.arn}/*",
    ]
  }

  statement {
    sid    = "InvalidarApenasEstaDistribuicao"
    effect = "Allow"

    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
    ]

    resources = [aws_cloudfront_distribution.site.arn]
  }
}

resource "aws_iam_role_policy" "lp_deploy" {
  name   = "bruma-lp-deploy-policy"
  role   = aws_iam_role.lp_deploy.id
  policy = data.aws_iam_policy_document.lp_deploy_permissions.json
}

output "lp_deploy_role_arn" {
  description = "ARN da role usada pelo workflow .github/workflows/deploy-lp.yml"
  value       = aws_iam_role.lp_deploy.arn
}

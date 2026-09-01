# =============================================================================
# OIDC do GitHub Actions - MANTIDO, mas AINDA NAO EM USO
#
# STATUS EM 01/09/2026:
#   Estes dois recursos EXISTEM na conta e estao PARADOS. O pipeline de deploy
#   nao usa OIDC hoje - usa o usuario IAM descrito em github_ci_user.tf.
#
#   Eles nao foram apagados de proposito: a coordenacao do hackathon esta
#   avaliando liberar `sts:AssumeRoleWithWebIdentity` na conta. Se liberarem,
#   OIDC volta a ser o caminho (credencial temporaria em vez de chave de longa
#   duracao) trocando so o passo de autenticacao do workflow e removendo os
#   secrets AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY do repositorio.
#
# POR QUE NAO FUNCIONOU:
#   O provedor e a role foram criados corretamente. O CloudTrail confirmou que
#   o `sub` e o `aud` do token do GitHub batiam exatamente com a trust policy,
#   e a AWS respondeu AccessDenied mesmo assim. Repetimos o teste com a
#   condicao do `sub` totalmente aberta (`repo:paty127/wizard-resilience-aws:*`)
#   e o erro persistiu - o que descarta a trust policy e aponta para restricao
#   da organizacao AWS acima desta conta. Coerente com o CloudShell tambem
#   estar bloqueado e com a policy Hackathon-FullAccess-Workshop ser uma lista
#   branca de servicos sem `sts:`.
#
# >>> PENDENCIA DE SEGURANCA <<<
#   A role na conta esta com a condicao do `sub` AFROUXADA
#   (`repo:paty127/wizard-resilience-aws:*`), sobra do teste de diagnostico.
#   O codigo abaixo ja tem o valor correto, travado na branch. Assim que
#   alguem rodar o import + apply, a condicao volta ao lugar. Enquanto isso,
#   qualquer branch do repositorio poderia assumir a role - hoje inofensivo,
#   porque a federacao esta bloqueada de qualquer forma.
#
# COMO ADOTAR NO TERRAFORM (senao o apply falha com EntityAlreadyExists):
#   terraform import aws_iam_openid_connect_provider.github \
#     arn:aws:iam::140825045811:oidc-provider/token.actions.githubusercontent.com
#   terraform import aws_iam_role.lp_deploy bruma-lp-deploy
#
# COMO REMOVER, se a coordenacao disser que nao vai liberar: ROLLBACK.md.
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

# As tags obrigatorias de team/project/environment vem do `default_tags` do
# provider (providers.tf). Os dois recursos foram criados a mao sem elas; o
# primeiro apply depois do import corrige.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    component = "lp-deploy"
  }
}

# Confianca restrita: so a branch da LP. Push na main, em outra branch ou em um
# fork nao consegue assumir esta role.
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
  description = "Deploy da LP via GitHub Actions OIDC. Parada: a conta nao permite sts:AssumeRoleWithWebIdentity. Ver github_oidc.tf."

  assume_role_policy = data.aws_iam_policy_document.lp_deploy_trust.json

  tags = {
    component = "lp-deploy"
  }
}

# Mesmo escopo do usuario IAM em uso: sem s3:DeleteObject, so os dois buckets
# de origem, so esta distribuicao.
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

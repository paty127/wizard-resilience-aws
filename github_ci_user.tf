# =============================================================================
# CI/CD da Landing Page - identidade usada pelo GitHub Actions
#
# CONTEXTO PARA QUEM FOR APLICAR (Patricia / quem tiver o tfstate):
#
#   O usuario `bruma-lp-deploy-ci` e a policy abaixo JA EXISTEM na conta.
#   Foram criados a mao pelo console em 31/08/2026 porque o tfstate e local e
#   nao estava na maquina de quem montou o pipeline. Este arquivo e a versao
#   versionada dos mesmos recursos, para que eles parem de ser infra invisivel.
#
#   A CHAVE DE ACESSO NAO ESTA AQUI E NAO DEVE ESTAR. Ela foi gerada pelo
#   console e guardada direto nos secrets do repositorio (AWS_ACCESS_KEY_ID e
#   AWS_SECRET_ACCESS_KEY). Terraform gravaria a chave em texto claro no
#   tfstate, entao `aws_iam_access_key` fica deliberadamente de fora.
#
#   Para adotar sem recriar (senao o apply falha com EntityAlreadyExists),
#   rode o import UMA VEZ antes do primeiro apply:
#
#     terraform import aws_iam_user.lp_deploy_ci bruma-lp-deploy-ci
#
#   Depois disso o `terraform plan` deve sair limpo e o teardown.sh passa a
#   limpar isso junto, sem deixar usuario orfao.
#
#   Se preferir NAO adotar: apague o usuario no console (IAM > Usuarios >
#   bruma-lp-deploy-ci) e delete este arquivo. Nada mais depende dele.
#
# POR QUE NAO OIDC (que seria a pratica recomendada):
#   Tentamos primeiro com OIDC, sem chave estatica. Nao funciona nesta conta.
#   O provedor e a role foram criados corretamente e o CloudTrail confirmou que
#   o `sub` e o `aud` do token batiam exatamente com a trust policy - a AWS
#   respondeu AccessDenied em sts:AssumeRoleWithWebIdentity mesmo assim.
#   Repetimos com a condicao do `sub` totalmente aberta e o erro persistiu, o
#   que descarta a trust policy e aponta para restricao da organizacao AWS
#   acima desta conta (o CloudShell tambem e bloqueado, e a policy
#   Hackathon-FullAccess-Workshop e uma lista branca sem `sts:`).
#   Se o `sts:` for liberado, vale voltar para OIDC: e mais seguro, porque usa
#   credencial temporaria em vez de chave de longa duracao.
# =============================================================================

resource "aws_iam_user" "lp_deploy_ci" {
  name = "bruma-lp-deploy-ci"

  # As tags obrigatorias de team/project/environment vem do `default_tags` do
  # provider (providers.tf). O usuario foi criado a mao sem elas; o primeiro
  # apply depois do import corrige isso e remove a tag malformada que sobrou.
  tags = {
    component = "lp-deploy"
    descricao = "Usado pelo workflow .github/workflows/deploy-lp.yml"
  }
}

# --- Permissoes: minimo necessario, sem delete ------------------------------
# Deliberadamente SEM s3:DeleteObject. O pipeline consegue escrever e
# sobrescrever, nunca apagar. Combinado com o versionamento ligado nos dois
# buckets, qualquer publicacao e reversivel (ver ROLLBACK.md).
#
# O raio de dano de um vazamento da chave e proposital pequeno: escrever
# arquivo em dois buckets de LP e limpar o cache de uma distribuicao. Lambda,
# DynamoDB, SQS, WAF e Route 53 ficam fora de alcance.
data "aws_iam_policy_document" "lp_deploy_ci" {
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

resource "aws_iam_user_policy" "lp_deploy_ci" {
  name   = "bruma-lp-deploy-ci-policy"
  user   = aws_iam_user.lp_deploy_ci.name
  policy = data.aws_iam_policy_document.lp_deploy_ci.json
}

output "lp_deploy_ci_user_arn" {
  description = "Usuario IAM usado pelo workflow .github/workflows/deploy-lp.yml"
  value       = aws_iam_user.lp_deploy_ci.arn
}

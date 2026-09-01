# Rollback do deploy da Landing Page

Este documento cobre como desfazer, no todo ou em parte, a publicacao
automatica da LP feita pelo workflow `.github/workflows/deploy-lp.yml`.

Nada aqui e urgente ou perigoso: **o versionamento esta ligado nos dois buckets
de origem** (`s3.tf`, `aws_s3_bucket_versioning`), entao nenhuma versao anterior
foi perdida.

---

## O que o deploy alterou

| Bucket | Regiao |
|---|---|
| `case-b-resilience-origin-primary-9efb5828` | us-east-1 |
| `case-b-resilience-origin-secondary-9efb5828` | sa-east-1 |

Em cada um deles:

- **`index.html`** — objeto que ja existia (versao de 29/08/2026, 14.895 bytes),
  foi **sobrescrito** pela LP nova. A versao antiga continua guardada.
- **15 objetos novos** — `exemplo.html`, `dossie.html`, `favicon.ico`,
  `favicon.svg`, `data/units-sp.json` e `_astro/*` (CSS, JS e imagens webp).

O pipeline roda `aws s3 sync` **sem `--delete`**, e o usuario de deploy
(`bruma-lp-deploy-ci`) **nao tem permissao de `s3:DeleteObject`**. Nenhum objeto
foi ou pode ser apagado por ele.

> Publicado com sucesso em 31/08/2026 (run "Deploy LP #2", commit `7fd7649`).
> Conferido no ar: `/` = LP nova, `/exemplo.html` e `/dossie.html`, nos dois
> buckets.

---

## Cenario 1 — voltar o site para a versao anterior

### Pelo console (mais simples)

1. S3 > `case-b-resilience-origin-primary-9efb5828`
2. Ligue o toggle **"Mostrar versoes"**
3. Clique em `index.html` e localize a versao de **29/08/2026 22:42** (14,5 KB)
4. Selecione essa versao > **Acoes** > **Restaurar** (ou baixe e reenvie)
5. Repita no bucket `case-b-resilience-origin-secondary-9efb5828` (regiao sa-east-1)
6. Invalide o cache: CloudFront > `E11LVFDZKEUA69` > **Invalidacoes** > criar com o path `/*`

### Pela CLI

```bash
# Descobrir o VersionId antigo do index.html
aws s3api list-object-versions \
  --bucket case-b-resilience-origin-primary-9efb5828 \
  --prefix index.html \
  --query 'Versions[].{Id:VersionId,Data:LastModified,Tam:Size}' --output table

# Restaurar copiando a versao antiga por cima da atual
aws s3api copy-object \
  --bucket case-b-resilience-origin-primary-9efb5828 \
  --key index.html \
  --copy-source "case-b-resilience-origin-primary-9efb5828/index.html?versionId=COLE_O_VERSION_ID"

# Idem no secundario (trocar o nome do bucket e usar --region sa-east-1)

# Limpar o cache
aws cloudfront create-invalidation --distribution-id E11LVFDZKEUA69 --paths "/*"
```

Os 15 arquivos novos continuam la, mas ficam orfaos: ninguem os acessa se o
`index.html` antigo voltar. Custam menos de um centavo por mes. Se quiser
limpar mesmo assim, veja o cenario 3.

---

## Cenario 2 — parar o deploy automatico, mantendo o que ja esta no ar

Apague o arquivo do workflow na branch `site-frontend`:

```bash
git rm .github/workflows/deploy-lp.yml && git commit -m "Desativa deploy automatico da LP" && git push
```

Sem o arquivo, o GitHub Actions nao tem o que executar. O site continua no ar
exatamente como esta.

---

## Cenario 3 — remover tudo que foi adicionado

**1. Apagar os objetos novos** (precisa de credencial com permissao de delete —
o usuario do pipeline nao tem):

```bash
for B in case-b-resilience-origin-primary-9efb5828 case-b-resilience-origin-secondary-9efb5828; do
  aws s3 rm "s3://$B/_astro/" --recursive
  aws s3 rm "s3://$B/data/" --recursive
  aws s3 rm "s3://$B/exemplo.html"
  aws s3 rm "s3://$B/dossie.html"
  aws s3 rm "s3://$B/favicon.ico"
  aws s3 rm "s3://$B/favicon.svg"
done
```

**2. Remover a identidade do pipeline.** Duas opcoes:

- **Se voce ja adotou no Terraform** (rodou o `terraform import` descrito em
  `github_ci_user.tf`): apague o arquivo `github_ci_user.tf` e rode
  `terraform apply`. Ou, para derrubar tudo, `terraform destroy` ja leva junto.

- **Se ainda nao adotou:** IAM > Usuarios > `bruma-lp-deploy-ci` > Excluir.
  Isso invalida a chave de acesso junto, entao o pipeline para de autenticar
  na hora.

**3. Apagar os secrets do repositorio** — GitHub > Settings > Secrets and
variables > Actions > remover `AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`.

**4. Apagar o workflow** — cenario 2 acima.

Nenhum desses passos toca em CloudFront, WAF, Route 53, Lambda, SQS, DynamoDB
ou nos buckets em si. A infra do case fica intacta.

---

## Pendencia — dois recursos orfaos da tentativa com OIDC

Antes de chegar no usuario IAM, tentamos autenticar via OIDC. Nao funciona
nesta conta (detalhes no cabecalho de `.github/workflows/deploy-lp.yml` e em
`github_ci_user.tf`). Ficaram dois recursos que **nao sao usados por nada** e
podem ser apagados a qualquer momento:

1. IAM > Funcoes > `bruma-lp-deploy` > Excluir
2. IAM > Provedores de identidade > `token.actions.githubusercontent.com` > Excluir

Apague nesta ordem — a role depende do provedor.

> Se voces conseguirem liberar `sts:AssumeRoleWithWebIdentity` com quem
> administra a organizacao AWS, vale manter os dois e voltar para OIDC: e mais
> seguro que chave de longa duracao. Nesse caso a role precisa ter a condicao
> do `sub` apertada de volta para
> `repo:paty127/wizard-resilience-aws:ref:refs/heads/site-frontend` — ela ficou
> com `repo:paty127/wizard-resilience-aws:*` por causa do teste de diagnostico.

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

## Pendencias conhecidas

### 1. `terraform destroy` nao completava — RESOLVIDO (03/09/2026)

Nenhum dos tres buckets (`origin_primary`, `origin_secondary`, `fallback`) tinha
`force_destroy = true`, e os tres ficam com versionamento ligado e com objetos
dentro. O `terraform destroy` — e portanto o `teardown.sh` — falhava com
`BucketNotEmpty`.

Corrigido em `s3.tf` e `route53.tf` (`force_destroy = true` nos tres). Falta
apenas rodar `terraform apply` (de quem tem o tfstate local) pra essa mudanca
valer antes do teardown final.

### 2. Recursos do OIDC mantidos de proposito

A role `bruma-lp-deploy` e o provedor `token.actions.githubusercontent.com`
existem mas estao parados — a autenticacao real e pelo usuario IAM. Nao foram
apagados porque a coordenacao do hackathon esta avaliando liberar
`sts:AssumeRoleWithWebIdentity`. Contexto completo em `github_oidc.tf`.

Se a resposta for negativa, apague nesta ordem (a role depende do provedor):

1. IAM > Funcoes > `bruma-lp-deploy` > Excluir
2. IAM > Provedores de identidade > `token.actions.githubusercontent.com` > Excluir

> Enquanto ficarem: a role esta com a condicao do `sub` afrouxada
> (`repo:paty127/wizard-resilience-aws:*`), sobra do teste de diagnostico. O
> valor correto ja esta em `github_oidc.tf` e volta ao lugar no primeiro apply
> depois do import. Hoje e inofensivo, porque a federacao esta bloqueada de
> qualquer forma.

### 3. O tfstate e local

Nao ha backend remoto configurado, entao o state vive na maquina de quem
aplicou. Na pratica, so essa pessoa consegue executar o teardown.

---

## Recurso novo: URL curta para a demo ao vivo (03/09/2026)

Adicionado `url_redirect.tf` — um bucket S3 (`wizard-bruma`) configurado como
website estatico em modo redirecionamento, so pra dar um endereco curto e
decoravel pra demonstracao ao vivo do slide 7 (o dominio real do CloudFront e
um hash aleatorio tipo `d3fwxqahz0kapg.cloudfront.net`, impossivel de
decorar). Nao registramos dominio proprio (custaria dinheiro) — o bucket
redireciona (`http://wizard-bruma.s3-website-us-east-1.amazonaws.com`, ver
output `short_url`) via HTTP 301 pro CloudFront real em HTTPS.

Bucket vazio, sem objetos, sem politica publica — so a config de website
hosting. Custo: zero (bem abaixo do free tier). **Nao precisa de passo manual
de teardown**: cai junto no `terraform destroy` / `teardown.sh`, igual todo o
resto.

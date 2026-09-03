# "URL curta" para a demonstração ao vivo (slide 7), sem comprar domínio.
#
# Truque: nomes de bucket S3 são escolhidos por nós e únicos globalmente,
# então funcionam como um "endereço memorizável" com custo estimado
# desprezível para a demo (a AWS tarifa requisições S3, mas o volume aqui
# é irrisório: só os hits do redirect durante a apresentação). O bucket fica
# configurado como website estático em modo "redirect all requests", que
# devolve um 301 pro domínio real do CloudFront - sem precisar de ACM nem
# de um domínio de verdade.
#
# Limitação: o endpoint de website hosting do S3 só existe em HTTP (para
# HTTPS seria necessário domínio próprio + certificado ACM, que é
# exatamente o que estamos evitando aqui). O redirecionamento em si leva
# o visitante pro CloudFront já em HTTPS.
resource "aws_s3_bucket" "url_redirect" {
  bucket        = var.short_url_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "url_redirect" {
  bucket = aws_s3_bucket.url_redirect.id

  redirect_all_requests_to {
    host_name = aws_cloudfront_distribution.site.domain_name
    protocol  = "https"
  }
}

resource "aws_route53_zone" "primary" {
  name = var.domain_name
}

# Health check monitora o próprio CloudFront (que já faz failover interno
# entre os buckets S3 primário/secundário). Esse health check cobre o
# cenário extremo de falha total do CloudFront/origem.
resource "aws_route53_health_check" "cloudfront" {
  fqdn              = aws_cloudfront_distribution.site.domain_name
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = 2
  request_interval  = 10

  tags = {
    Name = "${var.project_tag}-cloudfront-health-check"
  }
}

# --- Registro primário: aponta para o CloudFront, com health check ---
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.cloudfront.id

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = true
  }
}

# --- Bucket S3 estático com página de fallback, usado como registro secundário ---
# Ativado automaticamente pelo Route 53 se o health check do CloudFront falhar.
resource "aws_s3_bucket" "fallback" {
  bucket = "${var.project_tag}-dns-fallback-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_website_configuration" "fallback" {
  bucket = aws_s3_bucket.fallback.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "fallback" {
  bucket                  = aws_s3_bucket.fallback.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "fallback_public_read" {
  bucket = aws_s3_bucket.fallback.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadFallback"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.fallback.arn}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.fallback]
}

resource "aws_s3_object" "fallback_page" {
  bucket       = aws_s3_bucket.fallback.id
  key          = "index.html"
  content_type = "text/html"
  content      = <<-HTML
    <!DOCTYPE html>
    <html lang="pt-br">
    <head><meta charset="utf-8"><title>Wizard - Manutenção</title></head>
    <body style="font-family: sans-serif; text-align: center; padding-top: 10%;">
      <h1>Estamos de volta em instantes</h1>
      <p>Nossa equipe já está resolvendo. Tente novamente em alguns minutos.</p>
    </body>
    </html>
  HTML
}

# --- Registro secundário: aponta para o bucket de fallback estático ---
resource "aws_route53_record" "secondary" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.subdomain}.${var.domain_name}"
  type    = "A"

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"

  alias {
    name                   = aws_s3_bucket_website_configuration.fallback.website_domain
    zone_id                = aws_s3_bucket.fallback.hosted_zone_id
    evaluate_target_health = false
  }
}

# Nota: AWS Shield Standard é ativado automaticamente em todo recurso
# CloudFront/Route 53 - não requer configuração de código.

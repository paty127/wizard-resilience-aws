# Certificado TLS - só é criado quando enable_custom_domain = true.
# Enquanto o domínio for placeholder, o ACM não consegue validar via DNS
# (o domínio não existe de verdade), então esses recursos ficam desligados
# por padrão (count = 0) para não travar o apply.

# ACM precisa estar em us-east-1 para ser usado pelo CloudFront
resource "aws_acm_certificate" "site" {
  count = var.enable_custom_domain ? 1 : 0

  domain_name       = "${var.subdomain}.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_custom_domain ? {
    for dvo in aws_acm_certificate.site[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "site" {
  count = var.enable_custom_domain ? 1 : 0

  certificate_arn         = aws_acm_certificate.site[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Origin Access Control - restringe acesso aos buckets S3 apenas via CloudFront
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_tag}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = var.enable_custom_domain ? ["${var.subdomain}.${var.domain_name}"] : []
  web_acl_id          = aws_wafv2_web_acl.site.arn

  origin {
    domain_name              = aws_s3_bucket.origin_primary.bucket_regional_domain_name
    origin_id                = "s3-primary"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  origin {
    domain_name              = aws_s3_bucket.origin_secondary.bucket_regional_domain_name
    origin_id                = "s3-secondary"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  origin_group {
    origin_id = "s3-failover-group"

    failover_criteria {
      status_codes = [403, 404, 500, 502, 503, 504]
    }

    member {
      origin_id = "s3-primary"
    }

    member {
      origin_id = "s3-secondary"
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods          = ["GET", "HEAD"]
    target_origin_id        = "s3-failover-group"
    viewer_protocol_policy  = "redirect-to-https"
    compress                = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # Sem domínio customizado: usa o certificado padrão *.cloudfront.net (HTTPS já funciona).
    # Com domínio customizado (enable_custom_domain = true): usa o certificado ACM validado.
    cloudfront_default_certificate = !var.enable_custom_domain
    acm_certificate_arn            = var.enable_custom_domain ? aws_acm_certificate_validation.site[0].certificate_arn : null
    ssl_support_method             = var.enable_custom_domain ? "sni-only" : null
    minimum_protocol_version       = var.enable_custom_domain ? "TLSv1.2_2021" : null
  }
}

# --- Bucket policies: acesso exclusivo via OAC da distribuição acima ---

data "aws_iam_policy_document" "origin_primary" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.origin_primary.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "origin_primary" {
  bucket = aws_s3_bucket.origin_primary.id
  policy = data.aws_iam_policy_document.origin_primary.json
}

data "aws_iam_policy_document" "origin_secondary" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.origin_secondary.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "origin_secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.origin_secondary.id
  policy   = data.aws_iam_policy_document.origin_secondary.json
}

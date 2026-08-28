resource "aws_wafv2_web_acl" "site" {
  name        = "${var.project_tag}-web-acl"
  description = "WAF para a vitrine digital da Wizard - proteção L7"
  scope       = "CLOUDFRONT" # WebACL para CloudFront deve ser criada em us-east-1

  default_action {
    allow {}
  }

  # Regra 1: proteção genérica (SQLi, path traversal, etc.)
  rule {
    name     = "AWS-CommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # Regra 2: payloads conhecidos de exploração
  rule {
    name     = "AWS-KnownBadInputs"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  # Regra 3: rate limiting por IP (força bruta / DDoS de aplicação)
  rule {
    name     = "RateLimitPerIP"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_tag}-web-acl"
    sampled_requests_enabled   = true
  }
}

# Bot Control (opcional, tem custo adicional) - deixado comentado.
# Descomentar se quisermos mitigar bots de spam nos formulários de leads.
#
# rule {
#   name     = "AWS-BotControl"
#   priority = 4
#   override_action { none {} }
#   statement {
#     managed_rule_group_statement {
#       name        = "AWSManagedRulesBotControlRuleSet"
#       vendor_name = "AWS"
#     }
#   }
#   visibility_config {
#     cloudwatch_metrics_enabled = true
#     metric_name                = "bot-control"
#     sampled_requests_enabled   = true
#   }
# }

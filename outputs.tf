output "site_url" {
  description = "URL pública do site"
  value       = "https://${var.subdomain}.${var.domain_name}"
}

output "cloudfront_domain_name" {
  description = "Domínio da distribuição CloudFront"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "cloudfront_distribution_id" {
  description = "ID da distribuição CloudFront (usado no Game Day / FIS)"
  value       = aws_cloudfront_distribution.site.id
}

output "route53_zone_id" {
  description = "ID da hosted zone - usar para configurar os nameservers no registrador"
  value       = aws_route53_zone.primary.zone_id
}

output "route53_nameservers" {
  description = "Nameservers a configurar no registrador do domínio"
  value       = aws_route53_zone.primary.name_servers
}

output "short_url" {
  description = "URL curta/memorizável pra demo ao vivo (slide 7) - redireciona (HTTP 301) pro CloudFront real em HTTPS. Precisa digitar o http:// na frente."
  value       = "http://${aws_s3_bucket_website_configuration.url_redirect.website_endpoint}"
}

output "s3_bucket_primary" {
  description = "Bucket S3 primário (us-east-1) - time de Backend faz o deploy do site aqui"
  value       = aws_s3_bucket.origin_primary.id
}

output "s3_bucket_secondary" {
  description = "Bucket S3 secundário (sa-east-1) - réplica de failover"
  value       = aws_s3_bucket.origin_secondary.id
}

output "waf_web_acl_arn" {
  description = "ARN do WAF WebACL"
  value       = aws_wafv2_web_acl.site.arn
}

output "health_check_id" {
  description = "ID do Route 53 Health Check (útil para o Game Day / CloudWatch)"
  value       = aws_route53_health_check.cloudfront.id
}

output "leads_api_url" {
  description = "URL do endpoint de captura de leads (POST /lead) - região primária"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}lead"
}

output "leads_api_url_secondary" {
  description = "URL do endpoint de captura de leads (POST /lead) - região secundária (failover)"
  value       = "${aws_apigatewayv2_stage.default_secondary.invoke_url}lead"
}

output "leads_queue_url" {
  description = "URL da fila SQS de leads (região primária)"
  value       = aws_sqs_queue.leads.url
}

output "leads_dlq_url" {
  description = "URL da Dead Letter Queue de leads (região primária)"
  value       = aws_sqs_queue.leads_dlq.url
}

output "leads_table_name" {
  description = "Nome da tabela DynamoDB de leads"
  value       = aws_dynamodb_table.leads.name
}

output "leads_lambda_function_name" {
  description = "Nome da função Lambda de captura de leads (útil para ver logs)"
  value       = aws_lambda_function.leads.function_name
}

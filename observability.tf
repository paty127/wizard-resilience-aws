# Habilita o Amazon GuardDuty para detecção de ameaças
resource "aws_guardduty_detector" "primary" {
  enable = true

  tags = {
    Name = "GuardDuty-Wizard-Bruma"
  }
}

# Tópico SNS para alertas de observabilidade
resource "aws_sns_topic" "alerts" {
  name = "wizard-infrastructure-alerts"
}

# Alarme CloudWatch para Erros 5xx no CloudFront
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_errors" {
  alarm_name          = "wizard-cloudfront-high-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 60
  statistic           = "Average"
  threshold           = 5 # Alerta se taxa de erro 5xx for maior que 5%
  alarm_description   = "Alarme de alta taxa de erros 5xx na borda (CloudFront)"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Region = "Global"
  }
}

# Alarme CloudWatch para Latência da API Gateway
resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "wizard-api-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Average"
  threshold           = 2000 # Alerta se latência ultrapassar 2000ms (2s)
  alarm_description   = "Alarme de latência elevada na recepção de leads"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

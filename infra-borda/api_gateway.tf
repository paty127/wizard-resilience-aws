resource "aws_apigatewayv2_api" "leads" {
  name          = "${var.project_tag}-leads-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"] # Ajustar para o domínio real quando disponível
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

resource "aws_apigatewayv2_integration" "leads" {
  api_id                 = aws_apigatewayv2_api.leads.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.leads.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "post_lead" {
  api_id    = aws_apigatewayv2_api.leads.id
  route_key = "POST /lead"
  target    = "integrations/${aws_apigatewayv2_integration.leads.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.leads.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 20
  }
}

# Permite que o API Gateway invoque a Lambda
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.leads.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.leads.execution_arn}/*/*"
}

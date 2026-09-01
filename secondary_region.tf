# =========================================================
# Backend replicado na região secundária (standby ativo)
# =========================================================
# Reaproveita o mesmo código das Lambdas (data.archive_file já definido em
# lambda.tf) e a mesma tabela DynamoDB (que já é Global Table - acessível
# nativamente na região secundária, sem precisar de config extra: o SDK
# do Lambda usa a região onde a própria função roda).

# --- Fila SQS + DLQ na região secundária ---
resource "aws_sqs_queue" "leads_dlq_secondary" {
  provider                  = aws.secondary
  name                      = "${var.project_tag}-leads-dlq-secondary"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "leads_secondary" {
  provider                   = aws.secondary
  name                       = "${var.project_tag}-leads-queue-secondary"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.leads_dlq_secondary.arn
    maxReceiveCount      = 3
  })
}

# --- Lambda de captura (intake) na região secundária ---
resource "aws_lambda_function" "leads_secondary" {
  provider      = aws.secondary
  function_name = "${var.project_tag}-leads-secondary"
  role          = aws_iam_role.lambda_leads.arn

  filename         = data.archive_file.lambda_leads.output_path
  source_code_hash = data.archive_file.lambda_leads.output_base64sha256

  handler = "leads.handler"
  runtime = "python3.12"
  timeout = 10

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.leads_secondary.url
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_leads_secondary" {
  provider          = aws.secondary
  name              = "/aws/lambda/${aws_lambda_function.leads_secondary.function_name}"
  retention_in_days = 14
}

# --- Lambda processadora na região secundária ---
resource "aws_lambda_function" "leads_processor_secondary" {
  provider      = aws.secondary
  function_name = "${var.project_tag}-leads-processor-secondary"
  role          = aws_iam_role.lambda_processor.arn

  filename         = data.archive_file.lambda_processor.output_path
  source_code_hash = data.archive_file.lambda_processor.output_base64sha256

  handler = "processor.handler"
  runtime = "python3.12"
  timeout = 10

  environment {
    variables = {
      TABLE_NAME              = aws_dynamodb_table.leads.name
      SES_REGION               = var.primary_region
      SES_SENDER_EMAIL          = var.ses_notification_email
      TEAM_NOTIFICATION_EMAIL   = var.ses_notification_email
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_processor_secondary" {
  provider          = aws.secondary
  name              = "/aws/lambda/${aws_lambda_function.leads_processor_secondary.function_name}"
  retention_in_days = 14
}

resource "aws_lambda_event_source_mapping" "leads_queue_trigger_secondary" {
  provider         = aws.secondary
  event_source_arn = aws_sqs_queue.leads_secondary.arn
  function_name    = aws_lambda_function.leads_processor_secondary.arn
  batch_size       = 5
}

# --- API Gateway na região secundária ---
resource "aws_apigatewayv2_api" "leads_secondary" {
  provider      = aws.secondary
  name          = "${var.project_tag}-leads-api-secondary"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

resource "aws_apigatewayv2_integration" "leads_secondary" {
  provider                = aws.secondary
  api_id                  = aws_apigatewayv2_api.leads_secondary.id
  integration_type        = "AWS_PROXY"
  integration_uri         = aws_lambda_function.leads_secondary.invoke_arn
  payload_format_version  = "2.0"
}

resource "aws_apigatewayv2_route" "post_lead_secondary" {
  provider  = aws.secondary
  api_id    = aws_apigatewayv2_api.leads_secondary.id
  route_key = "POST /lead"
  target    = "integrations/${aws_apigatewayv2_integration.leads_secondary.id}"
}

resource "aws_apigatewayv2_stage" "default_secondary" {
  provider    = aws.secondary
  api_id      = aws_apigatewayv2_api.leads_secondary.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 20
  }
}

resource "aws_lambda_permission" "apigw_secondary" {
  provider      = aws.secondary
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.leads_secondary.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.leads_secondary.execution_arn}/*/*"
}

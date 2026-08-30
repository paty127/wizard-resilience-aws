# --- Lambda de captura (intake) - recebe o POST /lead e manda pra fila SQS ---
data "archive_file" "lambda_leads" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/.terraform-build/lambda-leads.zip"
}

resource "aws_lambda_function" "leads" {
  function_name = "${var.project_tag}-leads"
  role          = aws_iam_role.lambda_leads.arn

  filename         = data.archive_file.lambda_leads.output_path
  source_code_hash = data.archive_file.lambda_leads.output_base64sha256

  handler = "leads.handler"
  runtime = "python3.12"
  timeout = 10

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.leads.url
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_leads" {
  name              = "/aws/lambda/${aws_lambda_function.leads.function_name}"
  retention_in_days = 14
}

# --- Lambda processadora - consome a fila SQS e grava no DynamoDB ---
data "archive_file" "lambda_processor" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-processor"
  output_path = "${path.module}/.terraform-build/lambda-processor.zip"
}

resource "aws_lambda_function" "leads_processor" {
  function_name = "${var.project_tag}-leads-processor"
  role          = aws_iam_role.lambda_processor.arn

  filename         = data.archive_file.lambda_processor.output_path
  source_code_hash = data.archive_file.lambda_processor.output_base64sha256

  handler = "processor.handler"
  runtime = "python3.12"
  timeout = 10

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.leads.name
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_processor" {
  name              = "/aws/lambda/${aws_lambda_function.leads_processor.function_name}"
  retention_in_days = 14
}

# Gatilho: liga a fila SQS na Lambda processadora automaticamente
resource "aws_lambda_event_source_mapping" "leads_queue_trigger" {
  event_source_arn = aws_sqs_queue.leads.arn
  function_name    = aws_lambda_function.leads_processor.arn
  batch_size       = 5
}

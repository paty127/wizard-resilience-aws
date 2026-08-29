# Empacota o código Python da pasta lambda/ num .zip automaticamente
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
      TABLE_NAME = aws_dynamodb_table.leads.name
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda_leads" {
  name              = "/aws/lambda/${aws_lambda_function.leads.function_name}"
  retention_in_days = 14
}

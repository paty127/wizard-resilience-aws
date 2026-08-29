# Secret Manager para armazenamento seguro de chaves de API / Integrações
resource "aws_secretsmanager_secret" "api_credentials" {
  name        = "wizard-api-integration-keys"
  description = "Credenciais e chaves de integracao para o sistema da Wizard"

  tags = {
    Name        = "Wizard-API-Secrets"
    Environment = "Production"
  }
}

resource "aws_secretsmanager_secret_version" "api_credentials_val" {
  secret_id     = aws_secretsmanager_secret.api_credentials.id
  secret_string = jsonencode({
    api_key     = "PLACEHOLDER_KEY_CHANGE_IN_AWS_CONSOLE"
    environment = "production"
  })
}

# Role do IAM para a Lambda de recepção de leads (Princípio do Menor Privilégio)
resource "aws_iam_role" "lambda_lead_execution_role" {
  name = "wizard-lambda-lead-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Policy para permitir escrita de logs no CloudWatch e acesso ao DynamoDB
resource "aws_iam_policy" "lambda_lead_policy" {
  name        = "wizard-lambda-lead-policy"
  description = "Permite gravacao de logs e escrita na tabela DynamoDB de leads"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/wizard-leads"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_policy" {
  role       = aws_iam_role.lambda_lead_execution_role.name
  policy_arn = aws_iam_policy.lambda_lead_policy.arn
}

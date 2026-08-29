resource "aws_iam_role" "lambda_leads" {
  name = "${var.project_tag}-lambda-leads-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Permissão básica de logs no CloudWatch (padrão AWS gerenciado)
resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_leads.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Privilégio mínimo: só grava (PutItem) na tabela de leads, nada mais.
data "aws_iam_policy_document" "lambda_dynamodb_write" {
  statement {
    sid       = "AllowPutItemOnLeadsTable"
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.leads.arn]
  }
}

resource "aws_iam_role_policy" "lambda_dynamodb_write" {
  name   = "${var.project_tag}-lambda-dynamodb-write"
  role   = aws_iam_role.lambda_leads.id
  policy = data.aws_iam_policy_document.lambda_dynamodb_write.json
}

# --- IAM da Lambda de captura (intake) ---
# A mesma Role é usada pelas Lambdas de intake nas regiões primária e secundária.
# As Roles IAM são globais e não pertencem a uma região específica.
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

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_leads.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Privilégio mínimo: publicar mensagens nas filas primária e secundária.
data "aws_iam_policy_document" "lambda_sqs_send" {
  statement {
    sid     = "AllowSendMessageToLeadsQueues"
    actions = ["sqs:SendMessage"]

    resources = [
      aws_sqs_queue.leads.arn,
      aws_sqs_queue.leads_secondary.arn,
    ]
  }
}

resource "aws_iam_role_policy" "lambda_sqs_send" {
  name   = "${var.project_tag}-lambda-sqs-send"
  role   = aws_iam_role.lambda_leads.id
  policy = data.aws_iam_policy_document.lambda_sqs_send.json
}

# --- IAM da Lambda processadora ---
# A mesma Role é reutilizada pelas processadoras das duas regiões.
resource "aws_iam_role" "lambda_processor" {
  name = "${var.project_tag}-lambda-processor-role"

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

resource "aws_iam_role_policy_attachment" "lambda_processor_basic_logs" {
  role       = aws_iam_role.lambda_processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Privilégio mínimo: consumir as duas filas, gravar a tabela de leads
# e enviar somente a notificação interna pelo SES.
# O ARN do DynamoDB usa "*" na região porque a mesma Role é utilizada
# pelas Lambdas processadoras das duas regiões.
data "aws_iam_policy_document" "lambda_processor_permissions" {
  statement {
    sid = "AllowConsumeLeadsQueues"

    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]

    resources = [
      aws_sqs_queue.leads.arn,
      aws_sqs_queue.leads_secondary.arn,
    ]
  }

  statement {
    sid       = "AllowPutItemOnLeadsTableAnyRegion"
    actions   = ["dynamodb:PutItem"]
    resources = ["arn:aws:dynamodb:*:*:table/${aws_dynamodb_table.leads.name}"]
  }

  statement {
    sid       = "AllowSendEmailViaSES"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = [aws_ses_email_identity.team.arn]
  }
}

resource "aws_iam_role_policy" "lambda_processor_permissions" {
  name   = "${var.project_tag}-lambda-processor-permissions"
  role   = aws_iam_role.lambda_processor.id
  policy = data.aws_iam_policy_document.lambda_processor_permissions.json
}

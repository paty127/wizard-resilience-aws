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
}

resource "aws_iam_role_policy" "lambda_processor_permissions" {
  name   = "${var.project_tag}-lambda-processor-permissions"
  role   = aws_iam_role.lambda_processor.id
  policy = data.aws_iam_policy_document.lambda_processor_permissions.json
}

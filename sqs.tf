# Dead Letter Queue: mensagens que falharam repetidamente caem aqui,
# preservando o lead pra investigação em vez de perder o dado.
resource "aws_sqs_queue" "leads_dlq" {
  name                      = "${var.project_tag}-leads-dlq"
  message_retention_seconds = 1209600 # 14 dias
}

resource "aws_sqs_queue" "leads" {
  name                       = "${var.project_tag}-leads-queue"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 dias

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.leads_dlq.arn
    maxReceiveCount      = 3
  })
}

# SES - identidade verificada para envio da notificação interna.
#
# Para a demo, o sistema envia somente uma notificação interna quando um
# novo lead é processado. O mesmo endereço verificado é usado como remetente
# e destinatário, permitindo o funcionamento mesmo com o SES em sandbox.
# Não é enviada confirmação automática para o endereço informado pelo lead.
resource "aws_ses_email_identity" "team" {
  email = var.ses_notification_email
}

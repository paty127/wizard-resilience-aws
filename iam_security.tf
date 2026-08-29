resource "aws_secretsmanager_secret" "api_credentials" {
  name        = "${var.project_tag}-api-integration-keys"
  description = "Container para credenciais/chaves de integracao do projeto Wizard"

  tags = {
    Name = "${var.project_tag}-secrets"
  }
}

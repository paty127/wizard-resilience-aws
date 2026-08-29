# Tabela de leads - capacidade On-Demand (paga por uso, absorve picos sem
# provisionamento manual, conforme documentado no Case B).
resource "aws_dynamodb_table" "leads" {
  name         = "${var.project_tag}-leads"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "lead_id"

  attribute {
    name = "lead_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  # Nota: Global Tables (replicação multi-região automática) fica fora do
  # escopo inicial para simplificar o primeiro apply. Para habilitar,
  # descomentar o bloco abaixo (exige que o provider secundário já esteja
  # configurado, o que já é o caso em providers.tf).
  #
  # replica {
  #   region_name = var.secondary_region
  # }
}

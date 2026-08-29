# Tabela DynamoDB com faturamento On-Demand (PAY_PER_REQUEST)
resource "aws_dynamodb_table" "wizard_leads" {
  name         = "wizard-leads"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # Configuração de Global Tables (Multi-Região para Alta Disponibilidade)
  # Cria uma réplica automática na região us-east-2 (Ohio)
  replica {
    region_name = "us-east-2"
  }

  tags = {
    Name        = "Wizard-Leads-Global-Table"
    Environment = "Production"
  }
}

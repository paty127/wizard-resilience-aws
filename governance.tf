# Configuração do AWS Budgets (Teto de $20 USD com alerta em 80%)
resource "aws_budgets_budget" "cost_control" {
  name              = "budget-hackathon-wizard-bruma"
  budget_type       = "COST"
  limit_amount      = "20"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["patricia.ferreira@exemplo.com"] # Substitua pelo seu e-mail
  }
}

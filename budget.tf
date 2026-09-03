# AWS Budget operacional para o ambiente do hackathon.
# O valor não representa um teto oficial da organização; pode ser alterado
# facilmente caso o mentor informe outro limite.
resource "aws_budgets_budget" "project_monthly" {
  name         = "${var.project_tag}-monthly-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    notification_type          = "ACTUAL"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    subscriber_email_addresses = [var.ses_notification_email]
  }
}

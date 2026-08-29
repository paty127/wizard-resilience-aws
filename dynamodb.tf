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
}

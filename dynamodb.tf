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

  # Global Tables (replica abaixo) exige Streams habilitado - sem isso a
  # AWS rejeita a operação.
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  replica {
    region_name = var.secondary_region
  }
}
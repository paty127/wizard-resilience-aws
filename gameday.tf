# IAM Role para execução do AWS FIS
resource "aws_iam_role" "fis_role" {
  name = "fis-game-day-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "fis.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fis_s3_attach" {
  role       = aws_iam_role.fis_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Template de experimento para simular falha na origem S3 primária no Game Day
resource "aws_fis_experiment_template" "s3_failover_game_day" {
  description = "Simulacao de Falha na Origem Primaria S3 - Game Day Wizard"
  role_arn    = aws_iam_role.fis_role.arn

  stop_condition {
    source = "none"
  }

  action {
    name      = "deny-s3-bucket-access"
    action_id = "aws:s3:bucket-policy-block"
    
    target = {
      ResourceType = "aws:s3:bucket"
      ResourceArn  = "arn:aws:s3:::wizard-primary-s3-bucket"
    }
  }

  target {
    name          = "primary_s3_bucket"
    resource_type = "aws:s3:bucket"
    selection_mode = "ALL"
    resource_arns = ["arn:aws:s3:::wizard-primary-s3-bucket"]
  }

  tags = {
    Name        = "FIS-GameDay-Wizard"
    Environment = "Production"
  }
}

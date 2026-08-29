# =========================================================
# Buckets de origem para o CloudFront (Origin Group com Failover)
# Conteúdo do site é gerenciado pelo time de Backend/Storage;
# aqui só provisionamos a infraestrutura de hospedagem + acesso restrito.
# =========================================================

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# --- Bucket primário (us-east-1) ---
resource "aws_s3_bucket" "origin_primary" {
  bucket = "${var.project_tag}-origin-primary-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "origin_primary" {
  bucket                  = aws_s3_bucket.origin_primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "origin_primary" {
  bucket = aws_s3_bucket.origin_primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

# --- Bucket secundário (sa-east-1) - réplica para failover ---
resource "aws_s3_bucket" "origin_secondary" {
  provider = aws.secondary
  bucket   = "${var.project_tag}-origin-secondary-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "origin_secondary" {
  provider                 = aws.secondary
  bucket                   = aws_s3_bucket.origin_secondary.id
  block_public_acls        = true
  block_public_policy      = true
  ignore_public_acls       = true
  restrict_public_buckets  = true
}

resource "aws_s3_bucket_versioning" "origin_secondary" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.origin_secondary.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Política: acesso exclusivo via CloudFront (OAC) - aplicada em cloudfront.tf
# após a distribuição ser criada, pois depende do ARN da distribuição.

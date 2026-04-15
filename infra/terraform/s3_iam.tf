# S3 Bucket and Lifecycle Policy for Loki Storage
# We use standard S3 with aggressive lifecycle rules for cost-efficiency.

resource "aws_s3_bucket" "loki_storage" {
  bucket = "loki-prod-storage-ematiq" # Change this if bucket name exists
  force_destroy = false # Protect data in production

  lifecycle {
    prevent_destroy = true # Mandatory safety lock for persistent data
  }
}

# Block all public access to the bucket
resource "aws_s3_bucket_public_access_block" "loki_storage" {
  bucket = aws_s3_bucket.loki_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce AES-256 server-side encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "loki_storage" {
  bucket = aws_s3_bucket.loki_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "loki_retention" {
  bucket = aws_s3_bucket.loki_storage.id

  rule {
    id     = "loki-logs-retention-30d"
    status = "Enabled"

    filter {} # Apply to all objects in the bucket

    expiration {
      days = 30 # Standard 30-day retention to avoid ballooning storage costs.
    }

    # Automatically move older objects to cheaper storage classes if not deleted
    transition {
      days          = 15
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

# IAM Policy for Loki Pods (Distributed Write/Read access)
resource "aws_iam_policy" "loki_s3_access" {
  name        = "LokiS3StorageAccessPolicy"
  description = "Minimal permissions for Loki to manage objects in S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.loki_storage.arn,
          "${aws_s3_bucket.loki_storage.arn}/*"
        ]
      }
    ]
  })
}

output "loki_s3_bucket" {
  value = aws_s3_bucket.loki_storage.id
}

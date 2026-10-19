
resource "aws_dynamodb_table" "ingestion_metadata" {
  name         = "${var.project_name}-${var.environment}-ingestion-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "batch_id"

  attribute {
    name = "batch_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

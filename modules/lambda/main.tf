
resource "aws_lambda_function" "ingestion" {
  function_name = "${var.project_name}-${var.environment}-ingestion"
  description   = "Validates JSON records and writes them to the S3 data lake"

  role             = var.lambda_role_arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = var.filename
  source_code_hash = var.source_code_hash
  timeout          = 30
  memory_size      = 128

  environment {
    variables = {
      DATA_LAKE_BUCKET = var.data_lake_bucket
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

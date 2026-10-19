data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project_name}-${var.environment}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "glue_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue" {
  name               = "${var.project_name}-${var.environment}-glue"
  assume_role_policy = data.aws_iam_policy_document.glue_assume_role.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

data "aws_iam_policy_document" "data_lake_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.data_lake_bucket_arn]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:AbortMultipartUpload"
    ]

    resources = ["${var.data_lake_bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "data_lake_access" {
  name   = "${var.project_name}-${var.environment}-data-lake-access"
  policy = data.aws_iam_policy_document.data_lake_access.json
}

resource "aws_iam_role_policy_attachment" "lambda_data_lake" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.data_lake_access.arn
}

resource "aws_iam_role_policy_attachment" "glue_data_lake" {
  role       = aws_iam_role.glue.name
  policy_arn = aws_iam_policy.data_lake_access.arn
}


data "aws_iam_policy_document" "lambda_metadata_access" {
  statement {
    effect = "Allow"

    actions = [
      "dynamodb:PutItem"
    ]

    resources = [var.metadata_table_arn]
  }
}

resource "aws_iam_policy" "lambda_metadata_access" {
  name   = "${var.project_name}-${var.environment}-lambda-metadata-access"
  policy = data.aws_iam_policy_document.lambda_metadata_access.json
}

resource "aws_iam_role_policy_attachment" "lambda_metadata_access" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_metadata_access.arn
}

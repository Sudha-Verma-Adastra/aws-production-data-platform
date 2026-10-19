
resource "aws_s3_object" "glue_script" {
  bucket = var.data_lake_bucket
  key    = "scripts/transform.py"
  source = var.glue_script_path
  etag   = filemd5(var.glue_script_path)

  content_type = "text/x-python"
}

resource "aws_glue_catalog_database" "analytics" {
  name = "${replace(var.project_name, "-", "_")}_${var.environment}_analytics"
}

resource "aws_glue_job" "transform" {
  name              = "${var.project_name}-${var.environment}-transform"
  role_arn          = var.glue_role_arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 10
  max_retries       = 0

  command {
    name            = "glueetl"
    script_location = "s3://${var.data_lake_bucket}/${aws_s3_object.glue_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--RAW_PATH"                         = "s3://${var.data_lake_bucket}/raw/"
    "--PROCESSED_PATH"                   = "s3://${var.data_lake_bucket}/processed/"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--job-bookmark-option"              = "job-bookmark-disable"
  }

  depends_on = [aws_s3_object.glue_script]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_glue_crawler" "processed" {
  name          = "${var.project_name}-${var.environment}-processed-crawler"
  role          = var.glue_role_arn
  database_name = aws_glue_catalog_database.analytics.name

  s3_target {
    path = "s3://${var.data_lake_bucket}/processed/"
  }

  schema_change_policy {
    update_behavior = "UPDATE_IN_DATABASE"
    delete_behavior = "LOG"
  }

  depends_on = [aws_glue_job.transform]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_athena_workgroup" "analytics" {
  name = "${var.project_name}-${var.environment}-analytics"

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${var.data_lake_bucket}/athena-results/"
    }
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

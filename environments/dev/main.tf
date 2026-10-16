module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

module "data_lake" {
  source = "../../modules/s3-data-lake"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

module "iam" {
  source = "../../modules/iam"

  project_name         = var.project_name
  environment          = var.environment
  data_lake_bucket_arn = module.data_lake.bucket_arn
}

data "archive_file" "lambda_ingestion" {
  type        = "zip"
  source_dir  = "${path.root}/../../applications/ingestion"
  output_path = "${path.root}/lambda_ingestion.zip"
}

module "lambda" {
  source = "../../modules/lambda"

  project_name     = var.project_name
  environment      = var.environment
  lambda_role_arn  = module.iam.lambda_role_arn
  data_lake_bucket = module.data_lake.bucket_name

  filename         = data.archive_file.lambda_ingestion.output_path
  source_code_hash = data.archive_file.lambda_ingestion.output_base64sha256
}

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

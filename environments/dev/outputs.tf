output "vpc_id" {
  value = module.networking.vpc_id
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "data_lake_bucket" {
  value = module.data_lake.bucket_name
}

output "lambda_role_arn" {
  value = module.iam.lambda_role_arn
}

output "glue_role_arn" {
  value = module.iam.glue_role_arn
}

output "lambda_function_name" {
  value = module.lambda.function_name
}

output "lambda_function_arn" {
  value = module.lambda.function_arn
}

output "glue_job_name" {
  value = module.glue.job_name
}

output "glue_crawler_name" {
  value = module.glue.crawler_name
}

output "glue_catalog_database" {
  value = module.glue.catalog_database
}

output "athena_workgroup" {
  value = module.glue.athena_workgroup
}

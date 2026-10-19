
output "job_name" {
  value = aws_glue_job.transform.name
}

output "crawler_name" {
  value = aws_glue_crawler.processed.name
}

output "catalog_database" {
  value = aws_glue_catalog_database.analytics.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.analytics.name
}

output "table_name" {
  value = aws_dynamodb_table.ingestion_metadata.name
}

output "table_arn" {
  value = aws_dynamodb_table.ingestion_metadata.arn
}

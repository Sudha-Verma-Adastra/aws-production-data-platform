
variable "project_name" {
  description = "Sandbox-compliant project prefix"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EMR cluster"
  type        = string
}

variable "data_lake_bucket_name" {
  description = "S3 data lake bucket name"
  type        = string
}

variable "data_lake_bucket_arn" {
  description = "S3 data lake bucket ARN"
  type        = string
}

variable "spark_script_s3_uri" {
  description = "S3 URI of the Spark processing script"
  type        = string
}

variable "release_label" {
  description = "EMR release label"
  type        = string
  default     = "emr-7.10.0"
}

variable "enabled" {
  description = "Enable EMR resources"
  type        = bool
  default     = false
}

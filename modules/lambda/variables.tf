
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "lambda_role_arn" {
  type = string
}

variable "data_lake_bucket" {
  type = string
}

variable "filename" {
  type = string
}

variable "source_code_hash" {
  type = string
}

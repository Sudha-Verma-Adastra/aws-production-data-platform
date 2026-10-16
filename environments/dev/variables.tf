variable "aws_region" {
  description = "AWS deployment region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "project_name" {
  type    = string
  default = "aws-prod-data-platform"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  cloud {
    organization = "sudha-adastra"

    workspaces {
      name = "aws-production-data-platform-dev"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-production-data-platform"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

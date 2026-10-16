# AWS Production Data Platform

A production-style AWS data engineering platform built with Terraform,
GitHub Actions, and HCP Terraform.

## Architecture

- Infrastructure as Code: Terraform
- CI/CD: GitHub Actions
- Remote Terraform execution and state: HCP Terraform
- Networking: Amazon VPC
- Data lake: Amazon S3
- Ingestion: AWS Lambda
- Processing metadata: Amazon DynamoDB
- ETL: AWS Glue
- Distributed processing: Amazon EMR
- SQL analytics: Amazon Athena
- Data warehouse: Amazon Redshift

## Environments

- dev
- staging
- prod

## Security principles

- Least-privilege IAM
- GitHub Actions OIDC
- Encrypted data storage
- No committed credentials or Terraform state
- Automated validation and security checks

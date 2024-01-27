/**
*   Local development only
*   Uses LocalStack for AWS services
*/

terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 3.0"
        }

        docker = {
            source  = "kreuzwerker/docker"
            version = "3.0.2"
        }
    }
}

provider "docker" {
    host = "npipe:////.//pipe//docker_engine" // Windows
    // host = "unix:///var/run/docker.sock" // Linux
}

provider "aws" {
    region = var.aws_region
    access_key  = var.aws_access_key
    secret_key  = var.aws_secret_key

    endpoints {
        dynamodb  = var.aws_endpoint
        s3        = var.aws_endpoint
        sts       = var.aws_endpoint
    }

    s3_force_path_style = length(var.aws_endpoint) > 0 ? true : false
}

# Used for generating unique buckets
data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "terraform_state" {
    bucket = "terraform-state"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
    name         = "terraform-state-lock"
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "LockID"

    attribute {
        name = "LockID"
        type = "S"
    }
}

variable "aws_region" {
    description = "The AWS region to deploy resources."
    type        = string
    default     = "us-west-2"
}

variable "aws_access_key" {
    description = "AWS access key for development; dummy value for LocalStack."
    type        = string
    default     = "test"
}

variable "aws_secret_key" {
    description = "AWS secret key for development; dummy value for LocalStack."
    type        = string
    default     = "test"
}

variable "aws_endpoint" {
    description = "The endpoint URL for aws services. Useful for localstack, ignore for CI/PROD."
    type        = string
    default     = "http://localhost:4566"
}

variable "environment" {
    description = "The environment to deploy resources."
    type        = string
    default     = "dev"
}

output endpoint {
    value = var.aws_endpoint
}

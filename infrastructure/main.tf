terraform {
    backend "s3" {
        bucket                       = "terraform-state"
        key                          = "terraform.tfstate"
        dynamodb_table               = "terraform-state-lock"
        region                       = "us-west-2"
        encrypt                      = true
        skip_requesting_account_id   = true

        endpoint = "http://s3.localhost.localstack.cloud:4566"
        dynamodb_endpoint = "http://localhost:4566"
        sts_endpoint = "http://localhost:4566"

        # endpoints = {
        #     dynamodb = "http://localhost:4566"
        #     s3       = "http://s3.localhost.localstack.cloud:4566"
        #     sts      = "http://localhost:4566"
        # }
    }

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
}

provider "aws" {
    region      = var.aws_region

    endpoints {
        iam       = var.aws_endpoint
        dynamodb  = var.aws_endpoint
        lambda    = var.aws_endpoint
        s3        = var.aws_endpoint == "" ? var.aws_endpoint : "http://s3.localhost.localstack.cloud:4566"
        sqs       = var.aws_endpoint
        sns       = var.aws_endpoint
        ssm       = var.aws_endpoint
        sts       = var.aws_endpoint
        ec2       = var.aws_endpoint
    }
}
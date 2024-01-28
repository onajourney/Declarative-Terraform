terraform {
    backend "s3" {
        key                          = "terraform.tfstate"
        dynamodb_table               = "terraform-state-lock"
        encrypt                      = true
    }

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 3.0"
        }
    }
}
variable "aws_region" {
    description = "The AWS region to deploy resources."
    type        = string
    default     = "us-west-2"
}

# variable "aws_access_key" {
#     description = "AWS access key for development; dummy value for LocalStack."
#     type        = string
#     default     = "test"
#     sensitive   = true
# }

# variable "aws_secret_key" {
#     description = "AWS secret key for development; dummy value for LocalStack."
#     type        = string
#     default     = "test"
#     sensitive   = true
# }

variable "aws_endpoint" {
    description = "The endpoint URL for aws services. Useful for localstack, ignore for CI/PROD."
    type        = string
    default     = "http://localhost:4566"
}

variable "docker_username" {
    description = "Docker registry username"
    type        = string
    sensitive   = true
    default     = ""
}

variable "docker_token" {
    description = "Docker registry password"
    type        = string
    sensitive   = true
    default     = ""
}

variable "docker_image_url" {
    description = "URL of the Docker image"
    type        = string
    default     = "http://localhost:5000/image:latest"
}

variable "environment" {
    description = "The environment to deploy resources."
    type        = string
    default     = "dev"
}

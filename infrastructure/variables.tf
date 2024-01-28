variable "aws_region" {
    description = "The AWS region to deploy resources."
    type        = string
    default     = "us-west-2"
}

# variable "docker_username" {
#     description = "Docker registry username"
#     type        = string
#     sensitive   = true
#     default     = ""
# }

# variable "docker_token" {
#     description = "Docker registry password"
#     type        = string
#     sensitive   = true
#     default     = ""
# }

# variable "docker_image_url" {
#     description = "URL of the Docker image"
#     type        = string
#     default     = "http://localhost:5000/image:latest"
# }

variable "environment" {
    description = "The environment to deploy resources."
    type        = string
    default     = "dev"
}

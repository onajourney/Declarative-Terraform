locals {
    default_handler = "index.handler"
    default_runtime = "nodejs18.x"
    default_timeout = 900 # 15 minutes, the maximum
    default_memory_size = 128 # Minimum memory (size in MB)
}

# Base resource
resource "aws_lambda_function" "lambda" {
    filename         = var.filename
    function_name    = var.function_name
    handler          = var.handler != null ? var.handler : local.default_handler
    role             = var.role_arn
    memory_size      = var.memory_size != null ? var.memory_size : local.default_memory_size
    source_code_hash = var.source_code_hash
    runtime          = var.runtime != null ? var.runtime : local.default_runtime
    timeout          = var.timeout != null ? var.timeout : local.default_timeout
    dynamic "environment" {
        for_each = length(var.environment.variables) > 0 ? [var.environment] : []
        content {
            variables = environment.value.variables
        }
    }
}

# User Input (Through JSON file)
variable "filename" {
    description = "The path to the function's deployment package within the local filesystem."
    type        = string
}

variable "function_name" {
    description = "The name of the Lambda function."
    type        = string
}

variable "handler" {
    description = "The function entrypoint in your code."
    type        = string
    default     = null
}

variable "memory_size" {
    description = "The amount of memory to allocate for the Lambda Function in MB."
    type        = number
    default     = null
}

variable "role_arn" {
    description = "ARN of the IAM role for the Lambda function"
    type        = string
}

variable "runtime" {
  description = "The identifier of the function's runtime."
  type        = string
  default     = null
}

variable "source_code_hash" {
    description = "Used to trigger updates. Must be set to a base64-encoded SHA256 hash of the package file specified with either filename or s3_key."
    type        = string
}

variable "timeout" {
    description = "The amount of time your Lambda Function has to run in seconds."
    type        = number
    default     = null
}

variable "environment" {
    description = "The environment variables for the Lambda function"
    type = object({
        variables = map(string)
    })
    default = {
        variables = {}
    }
}

# Required - As we use the arn values setup aws_lambda_permissions for sns
output "arn" {
    value = aws_lambda_function.lambda.arn
}

# # Required - as we are using this value as the visibility_timeout_seconds for sqs that reference a lambda
# output "timeouts" {
#     value = { for fn in aws_lambda_function.lambda : fn.function_name => fn.timeout }
# }
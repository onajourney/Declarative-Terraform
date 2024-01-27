locals {
    default_billing_mode   = "PAY_PER_REQUEST"
}

# Base resource
resource "aws_dynamodb_table" "table" {
    name           = var.name
    billing_mode   = local.default_billing_mode
    hash_key       = var.hash_key
    range_key      = var.range_key
    stream_enabled = var.stream_enabled
    stream_view_type = var.stream_view_type

    dynamic "attribute" {
        for_each = var.attributes
        content {
            name = attribute.value.name
            type = attribute.value.type
        }
    }

    dynamic "global_secondary_index" {
        for_each = var.gsi
        content {
            name               = global_secondary_index.value.name
            hash_key           = global_secondary_index.value.hash_key
            projection_type    = global_secondary_index.value.projection_type
        }
    }

    dynamic "local_secondary_index" {
        for_each = var.lsi
        content {
            name               = local_secondary_index.value.name
            range_key          = local_secondary_index.value.range_key
            projection_type    = local_secondary_index.value.projection_type
        }
    }

    tags = var.tags
}

# User Input (Through JSON file)
variable "name" {
    type = string
}

variable "hash_key" {
    type = string
}

variable "range_key" {
    type        = string
    description = "The sort key of the table. Required if LSIs are used."
    default     = null
}

variable "attributes" {
    type = list(object({
        name = string
        type = string
    }))
}

variable "gsi" {
    type = list(object({
        name            = string
        hash_key        = string
        projection_type = string
    }))
    default = []
}

variable "lsi" {
    type = list(object({
        name            = string
        range_key       = string
        projection_type = string
    }))
    default = []
}

variable "stream_enabled" {
    type        = bool
    default     = false
    description = "Enable DynamoDB Streams on the table."
}

variable "stream_view_type" {
    type        = string
    default     = null
    description = "The view type of the stream. Valid values are KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES."
}

variable "tags" {
    type    = map(string)
    default = {}
}

output "stream_arn" {
  value = aws_dynamodb_table.table.stream_arn
  description = "The ARN of the DynamoDB Stream."
}
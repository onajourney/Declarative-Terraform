locals {
  default_read_capacity  = 5
  default_write_capacity = 5
  default_billing_mode   = "PROVISIONED"
}

# Base resource
resource "aws_dynamodb_table" "table" {
    name           = var.name
    billing_mode   = local.default_billing_mode
    read_capacity  = local.default_read_capacity
    write_capacity = local.default_write_capacity
    hash_key       = var.hash_key

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
            write_capacity     = global_secondary_index.value.write_capacity
            read_capacity      = global_secondary_index.value.read_capacity
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
        write_capacity  = number
        read_capacity   = number
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

variable "tags" {
    type    = map(string)
    default = {}
}
# Allows us to handle resources in a declarative manner

locals {
    lambda_functions = toset(distinct([for file in fileset("${path.module}/resources/lambda", "**") : dirname(file)]))
    dynamodb_tables = fileset("${path.module}/resources/dynamodb", "*.json")
    ec2_instances = toset(distinct([for file in fileset("${path.module}/resources/ec2", "**") : dirname(file)]))
    parameters = fileset("${path.module}/resources/parameter", "*.json")
    s3_buckets = fileset("${path.module}/resources/s3", "*.json")
    sns_topics = fileset("${path.module}/resources/sns", "*.json")
    sqs_queues = fileset("${path.module}/resources/sqs", "*.json")
}

# Used for generating unique buckets
data "aws_caller_identity" "current" {}

# LOAD DYNAMODB TABLES
module "dynamodb_table" {
    for_each = {
        for file in local.dynamodb_tables : 
            trimsuffix(file, ".json") => jsondecode(file("${path.module}/resources/dynamodb/${file}"))
    }

    source     = "./modules/dynamodb"
    name       = each.value.name
    hash_key   = each.value.hash_key
    attributes = each.value.attributes

    gsi = try(each.value.gsi, [])
    lsi = try(each.value.lsi, [])
    tags = try(each.value.tags, {})
}

# CREATE EXECUTION ROLE FOR LAMBDA FUNCTIONS
resource "aws_iam_role" "lambda_role" {
    for_each = local.lambda_functions

    name = each.key

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Principal = {
                    Service = "lambda.amazonaws.com"
                },
                Action = "sts:AssumeRole"
            }
        ]
    })
}

# LOAD EC2 INSTANCES
data "aws_ami" "ami_lookup" {
    for_each = { 
        for instance in local.ec2_instances : instance => {
        config = jsondecode(file("${path.module}/resources/ec2/${instance}/config.json"))
        } if can(jsondecode(file("${path.module}/resources/ec2/${instance}/config.json")).ami.filters)
    }

    most_recent = each.value.ami.most_recent
    owners      = each.value.ami.owners

    dynamic "filter" {
        for_each = each.value.ami.filters
        content {
            name   = filter.value.name
            values = filter.value.values
        }
    }
}

resource "aws_instance" "instances" {
    for_each = { for instance in local.ec2_instances : instance => {
        config = jsondecode(file("${path.module}/resources/ec2/${instance}/config.json"))
        user_data_files = tolist(fileset("${path.module}/resources/ec2/${instance}", "user_data.*"))
    }}

    ami = (can(each.value.config["ami"]) && try(can(each.value.config["ami"]["filter"]), false) && length(try(each.value.config["ami"]["filter"], {})) > 0
        ? data.aws_ami.ami_lookup[each.key].id
        : each.value.config["ami"])

    instance_type = each.value.config.instance_type

    user_data = templatefile("${path.module}/resources/ec2/${each.key}/${each.value.user_data_files[0]}", {
        docker_username  = var.docker_username,
        docker_token     = var.docker_token,
        docker_image_url = var.docker_image_url
    })

    tags = merge(
        lookup(each.value.config, "tags", {}),
        {
            "Name" = each.key  # Using the key from the map as the Name tag
        }
    )
}

# LOAD LAMBDA FUNCTIONS
data "archive_file" "lambda_zip" {
    for_each = local.lambda_functions

    type        = "zip"
    source_dir  = "${path.module}/resources/lambda/${each.key}"
    output_path = "${path.root}/.terraform/tmp/${each.key}.zip"
    excludes    = ["config.json", "test.js"]

}

module "lambdas" {
    source = "./modules/lambda"

    for_each = local.lambda_functions

    filename      =  data.archive_file.lambda_zip[each.key].output_path
    function_name = each.key
    role_arn      = aws_iam_role.lambda_role[each.key].arn

    source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256
}

# LOAD S3 BUCKETS
resource "aws_s3_bucket" "buckets" {
    for_each = { for file in local.s3_buckets : trimsuffix(file, ".json") => null }

    # Buckets have to be globally unique
    bucket = "${each.key}-${var.environment}-${var.aws_region}-${data.aws_caller_identity.current.account_id}"
}

# Allow user to configure access block else default to true and let ACL handle permissions
resource "aws_s3_bucket_public_access_block" "public_access_block" {
    for_each = aws_s3_bucket.buckets

    bucket = each.value.id

    block_public_acls       = lookup(lookup(each.value, "public_access_block", {}), "block_public_acls", true)
    block_public_policy     = lookup(lookup(each.value, "public_access_block", {}), "block_public_policy", true)
    ignore_public_acls      = lookup(lookup(each.value, "public_access_block", {}), "ignore_public_acls", true)
    restrict_public_buckets = lookup(lookup(each.value, "public_access_block", {}), "restrict_public_buckets", true)
}

# Update ACL if necessary - if not specified AWS will default to "private"
resource "aws_s3_bucket_acl" "buckets_acl" {
    for_each = {
        for file in local.s3_buckets : 
            trimsuffix(file, ".json") => jsondecode(file("${path.module}/resources/s3/${file}"))
            if can(jsondecode(file("${path.module}/resources/s3/${file}")).acl) && jsondecode(file("${path.module}/resources/s3/${file}")).acl != "private"
    }

    bucket = aws_s3_bucket.buckets[each.key].id
    acl    = each.value.acl
}

# Update policy if necessary
resource "aws_s3_bucket_policy" "buckets_policy" {
    for_each = {
        for file in local.s3_buckets : 
            trimsuffix(file, ".json") => jsondecode(file("${path.module}/resources/s3/${file}"))
            if can(jsondecode(file("${path.module}/resources/s3/${file}")).policy)
    }

    bucket = aws_s3_bucket.buckets[each.key].id
    policy = jsonencode(each.value.policy)
}

# Implement trigger property - Grant S3 permission to invoke Lambda
resource "aws_lambda_permission" "s3_invoke_lambda" {
    for_each = {
        for idx, trigger in flatten([
            for file in local.s3_buckets : [
                for trigger in jsondecode(file("${path.module}/resources/s3/${file}")).trigger : {
                    bucket_key = trimsuffix(file, ".json")
                    lambda_function = trigger.lambda
                }
            ] if can(jsondecode(file("${path.module}/resources/s3/${file}")).trigger)
        ]) : "${trigger.bucket_key}-${idx}" => trigger
    }

    statement_id  = "AllowExecutionFromS3-${each.key}"
    action        = "lambda:InvokeFunction"
    function_name = module.lambdas[each.value.lambda_function].arn
    principal     = "s3.amazonaws.com"
    source_arn    = aws_s3_bucket.buckets[each.value.bucket_key].arn
}

# Implement trigger property - Create notification
resource "aws_s3_bucket_notification" "bucket_notification" {
    for_each = {
        for file in local.s3_buckets : 
            trimsuffix(file, ".json") => jsondecode(file("${path.module}/resources/s3/${file}"))
            if can(jsondecode(file("${path.module}/resources/s3/${file}")).trigger)
    }

    bucket = aws_s3_bucket.buckets[each.key].id

    dynamic "lambda_function" {
        for_each = [for trigger in each.value.trigger : {
            lambda_function_arn = module.lambdas[trigger.lambda].arn
            events              = trigger.events
            filter_prefix       = lookup(trigger, "filter_prefix", null)
            filter_suffix       = lookup(trigger, "filter_suffix", null)
        }]

        content {
            lambda_function_arn = lambda_function.value.lambda_function_arn
            events              = lambda_function.value.events
            filter_prefix       = lambda_function.value.filter_prefix
            filter_suffix       = lambda_function.value.filter_suffix
        }
    }

    depends_on = [aws_lambda_permission.s3_invoke_lambda]
}

# LOAD SNS TOPICS
resource "aws_sns_topic" "topics" {
    for_each = { for file in local.sns_topics : trimsuffix(file, ".json") => null }

    name = each.key
}

resource "aws_lambda_permission" "allow_sns" {
    for_each = {
        for entry in flatten([
            for file in local.sns_topics : [
                for lambda_function in flatten([jsondecode(file("${path.module}/resources/sns/${file}")).runLambda]) : {
                    topic = trimsuffix(file, ".json")
                    lambda_function = lambda_function
                }
            ]
        ]) : "${entry.topic}-${entry.lambda_function}" => entry
    }

    statement_id  = "AllowExecutionFromSNS-${each.key}"
    action        = "lambda:InvokeFunction"
    function_name = module.lambdas[each.value.lambda_function].arn
    principal     = "sns.amazonaws.com"
    source_arn    = aws_sns_topic.topics[each.value.topic].arn
}

resource "aws_sns_topic_subscription" "lambda_subscription" {
    for_each = {
        for entry in flatten([
            for file in local.sns_topics : [
                for lambda_function in flatten([jsondecode(file("${path.module}/resources/sns/${file}")).runLambda]) : {
                    topic = trimsuffix(file, ".json")
                    lambda_function = lambda_function
                }
            ]
        ]) : "${entry.topic}-${entry.lambda_function}" => entry
    }

    topic_arn = aws_sns_topic.topics[each.value.topic].arn
    protocol  = "lambda"
    endpoint  = module.lambdas[each.value.lambda_function].arn
}

# LOAD SQS QUEUES
resource "aws_sqs_queue" "queues" {
    for_each = {
        for file in local.sqs_queues : 
            trimsuffix(file, ".json") => jsondecode(file("${path.module}/resources/sqs/${file}"))
    }

    name                       = each.key
    # Visibility timeout can't be less than the timeout of the Lambda function
    # visibility_timeout_seconds = module.lambdas[each.value.runLambda].timeout
    visibility_timeout_seconds = 900
    message_retention_seconds  = lookup(each.value, "message_retention_seconds", 345600)
    delay_seconds              = lookup(each.value, "delay_seconds", null)
    max_message_size           = lookup(each.value, "max_message_size", null)
    receive_wait_time_seconds  = lookup(each.value, "receive_wait_time_seconds", null)
}

# Set up Lambda triggers for SQS queues
resource "aws_lambda_event_source_mapping" "sqs_lambda_trigger" {
    for_each = {
        for file in local.sqs_queues : 
        trimsuffix(file, ".json") => jsondecode(file("${path.module}/resources/sqs/${file}"))
        if can(jsondecode(file("${path.module}/resources/sqs/${file}")).runLambda) && 
            jsondecode(file("${path.module}/resources/sqs/${file}")).runLambda != ""
    }

    event_source_arn = aws_sqs_queue.queues[each.key].arn
    function_name    = module.lambdas[each.value.runLambda].arn
    # Other configurations like batch_size, enabled, etc.
}

resource "aws_iam_policy" "lambda_sqs_policy" {
    for_each = {
        for file in local.sqs_queues : 
        trimsuffix(file, ".json") => jsondecode(file("${path.module}/resources/sqs/${file}"))
        if can(jsondecode(file("${path.module}/resources/sqs/${file}")).runLambda) && 
            jsondecode(file("${path.module}/resources/sqs/${file}")).runLambda != ""
    }

    name        = "${each.key}_lambda_sqs_policy"
    description = "A policy to allow ${each.value.runLambda} lambda to interact with ${each.key} SQS"

    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "sqs:ReceiveMessage",
                    "sqs:DeleteMessage",
                    "sqs:GetQueueAttributes",
                    "sqs:SendMessage"
                ],
                Resource = aws_sqs_queue.queues[each.key].arn
            }
        ]
    })
}

# Attach SQS policy to lambda
resource "aws_iam_role_policy_attachment" "lambda_sqs_attachment" {
    for_each = {
        for file in local.sqs_queues : 
        trimsuffix(file, ".json") => jsondecode(file("${path.module}/resources/sqs/${file}"))
        if can(jsondecode(file("${path.module}/resources/sqs/${file}")).runLambda) && 
            jsondecode(file("${path.module}/resources/sqs/${file}")).runLambda != ""
    }

    role       = aws_iam_role.lambda_role[each.value.runLambda].name
    policy_arn = aws_iam_policy.lambda_sqs_policy[each.key].arn

    depends_on = [aws_iam_role.lambda_role, aws_iam_policy.lambda_sqs_policy]
}

resource "aws_ssm_parameter" "parameters" {
    for_each = {
        for file in local.parameters : 
            trimsuffix(file, ".json") => jsondecode(file("${path.module}/resources/parameter/${file}"))
    }

    name      = each.key
    type      = each.value.type
    value     = each.value.value
    overwrite = each.value.overwrite

    description = lookup(each.value, "description", null)
    tags = lookup(each.value, "tags", {})
}

output "instance_access_points" {
  value = {
    for instance in aws_instance.instances :
    instance.tags["Name"] => instance.public_ip
  }
}

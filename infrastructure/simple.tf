# /**
#  * START OF SIMPLE STREAM IMPLEMENTATION
#  * */

# resource "aws_iam_role" "lambda_exec_role" {
#   name = "lambda_exec_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Action = "sts:AssumeRole",
#         Effect = "Allow",
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         },
#       },
#     ],
#   })
# }

# resource "aws_iam_role_policy" "a_simple_log_policy" {
#     role = aws_iam_role.lambda_exec_role.name
#     name = "LambdaLogPolicy"

#     policy = jsonencode({
#       Version = "2012-10-17",
#       Statement = [
#         {
#           Effect = "Allow",
#           Action = [
#             "logs:CreateLogGroup",
#             "logs:CreateLogStream",
#             "logs:PutLogEvents"
#           ],
#           Resource = "arn:aws:logs:*:*:*"
#         },
#       ]
#     })
# }

# data "archive_file" "lambda_zip_simple" {
#     type        = "zip"
#     source_dir  = "${path.root}/resources/lambda/other"
#     output_path = "${path.root}/.terraform/tmp/simple.zip"
#     excludes    = ["package.json", "package-lock.json", "config.json", "test.js", "test.ts"]
# }

# resource "aws_lambda_function" "simple" {
#   filename         = "./.terraform/tmp/simple.zip"
#   function_name    = "simple"
#   role             = aws_iam_role.lambda_exec_role.arn
#   handler          = "index.handler"
#   source_code_hash = data.archive_file.lambda_zip_simple.output_base64sha256
#   runtime          = "nodejs18.x"

#   environment {
#     variables = {
#       TABLE_NAME = aws_dynamodb_table.simple.name
#     }
#   }
# }

# resource "aws_dynamodb_table" "simple" {
#   name           = "simple"
#   billing_mode   = "PAY_PER_REQUEST"
#   hash_key       = "id"

#   attribute {
#     name = "id"
#     type = "S"
#   }

#   stream_enabled   = true
#   stream_view_type = "NEW_AND_OLD_IMAGES"
# }

# # aws_lambda_permission and source mapping fail without the policy
# resource "aws_iam_role_policy" "simple_lambda_dynamodb_stream_policy" {
#     role = aws_iam_role.lambda_exec_role.name
#     name = "lambda_dynamodb_stream_policy"

#     policy = jsonencode({
#         Version = "2012-10-17",
#         Statement = [
#             {
#                 Effect = "Allow",
#                 Action = [
#                     "dynamodb:GetRecords",
#                     "dynamodb:GetShardIterator",
#                     "dynamodb:DescribeStream",
#                     "dynamodb:ListStreams"
#                 ],
#                 Resource = aws_dynamodb_table.simple.stream_arn
#             }
#         ]
#     })
# }

# resource "aws_lambda_permission" "allow_dynamodb" {
#   statement_id  = "AllowExecutionFromDynamoDB"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.simple.arn
#   principal     = "dynamodb.amazonaws.com"
#   source_arn    = aws_dynamodb_table.simple.stream_arn
# }

# resource "aws_lambda_event_source_mapping" "simple" {
#   event_source_arn  = aws_dynamodb_table.simple.stream_arn
#   function_name     = aws_lambda_function.simple.arn
#   starting_position = "LATEST"
# }

# /**
#  * END OF SIMPLE STREAM IMPLEMENTATION
#  * */
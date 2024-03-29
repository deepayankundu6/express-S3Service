terraform {
  backend "s3" {
    bucket = "deepayan-terraform-bucket"
    key    = "deepayan-terraform-bucket.tfstate"
    region = "ap-south-1"
  }
}

provider "aws" {
  region = "ap-south-1"
}
# Provisioning the s3 bucket for file upload
resource "aws_s3_bucket" "upload_file_bucket" {
  bucket = "deepayan-file-uploads-bucket"
}

# Creating and cofiguring the API gateway for lambda
resource "aws_api_gateway_rest_api" "my_api" {
  name        = "file-upload-api-gateway"
  description = "File upload lambda API Gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "gateway_path" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = "upload-s3"
}

resource "aws_api_gateway_stage" "default" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  deployment_id = aws_api_gateway_deployment.default.id
}
resource "aws_api_gateway_resource" "events_apig_resources_updatetags" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_resource.gateway_path.id
  path_part   = "{proxy+}"
}

# Creating API key for accessing the APIs
resource "aws_api_gateway_api_key" "APIKey" {
  name = "s3-uplaod-api-key"
}

resource "aws_api_gateway_usage_plan" "myusageplan" {
  name = "s3-upload-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.my_api.id
    stage  = aws_api_gateway_stage.default.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.APIKey.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.myusageplan.id
}

resource "aws_api_gateway_method" "proxy_get" {
  rest_api_id      = aws_api_gateway_rest_api.my_api.id
  resource_id      = aws_api_gateway_resource.events_apig_resources_updatetags.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
  request_parameters = {
    "method.request.path.proxy_get" = true
  }
}

resource "aws_api_gateway_method" "proxy_post" {
  rest_api_id      = aws_api_gateway_rest_api.my_api.id
  resource_id      = aws_api_gateway_resource.events_apig_resources_updatetags.id
  http_method      = "POST"
  authorization    = "NONE"
  api_key_required = true
  request_models = {
    "application/json"    = "Error",
    "multipart/form-data" = "Error"
  }
  request_parameters = {
    "method.request.path.proxy_post" = true
  }
}

# Creating the IAM roles for lambda
resource "aws_iam_role" "upload_lambda_role" {
  name = "upload-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Archiveing the lamda code and deploying it
data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/app"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "file_upload_lambda" {
  filename         = "${path.module}/lambda.zip"
  function_name    = "S3-upload-lambda-prod"
  role             = aws_iam_role.upload_lambda_role.arn
  handler          = "lambda.handler"
  runtime          = "nodejs20.x"
  memory_size      = 512
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  environment {
    variables = {
      BUCKET_NAME = "deepayan-file-uploads-bucket"
    }
  }
}

resource "aws_api_gateway_request_validator" "updatetag_request_validator" {
  name                        = "upload_lambda_request_validator"
  rest_api_id                 = aws_api_gateway_rest_api.my_api.id
  validate_request_body       = false
  validate_request_parameters = false
}

# Integrating the lambda with API gateway
resource "aws_api_gateway_integration" "lambda_integration_get" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.events_apig_resources_updatetags.id
  http_method             = aws_api_gateway_method.proxy_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.file_upload_lambda.invoke_arn
}

resource "aws_api_gateway_integration" "lambda_integration_post" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.events_apig_resources_updatetags.id
  http_method             = aws_api_gateway_method.proxy_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.file_upload_lambda.invoke_arn
}


resource "aws_api_gateway_deployment" "default" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id

  depends_on = [
    aws_api_gateway_method.proxy_post,
    aws_api_gateway_integration.lambda_integration_post,
    aws_api_gateway_method.proxy_get,
    aws_api_gateway_integration.lambda_integration_get
  ]
  lifecycle {
    create_before_destroy = true
  }
}

# Attaching the role for executing the lambda using API gateway
resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.file_upload_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.my_api.execution_arn}/*/*/*"
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.upload_lambda_role.name
}

# Attaching poliy to lambda for s3 bucket actions and API gateway execution
resource "aws_iam_policy" "policy" {
  name        = "file-upload-lambda-policy"
  description = "My test policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "s3:PutObject",
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.upload_file_bucket.arn}/*"
      },
      {
        Action   = "s3:PutObjectAcl",
        Effect   = "Allow",
        Resource = "${aws_s3_bucket.upload_file_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_2" {
  policy_arn = aws_iam_policy.policy.arn
  role       = aws_iam_role.upload_lambda_role.name
}

# Create cloud watch log group for the lambda
resource "aws_cloudwatch_log_group" "ts_lambda_loggroup" {
  name              = "/aws/lambda/S3-upload-lambda-prod"
  retention_in_days = 30
}

data "aws_iam_policy_document" "ts_lambda_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      aws_cloudwatch_log_group.ts_lambda_loggroup.arn,
      "${aws_cloudwatch_log_group.ts_lambda_loggroup.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "ts_lambda_role_policy" {
  policy = data.aws_iam_policy_document.ts_lambda_policy.json
  role   = aws_iam_role.upload_lambda_role.name
  name   = "my-lambda-policy"
}
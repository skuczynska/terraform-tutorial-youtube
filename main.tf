provider "aws" {
  region = "eu-central-1"
}

data "archive_file" "lambda-zip" {
  type        = "zip"
  source_file = "lambda.py"
  output_path = "lambda.zip"
}

resource "aws_iam_role" "skuczynska-lambda-iam" {
  name               = "skuczynska-lambda-iam"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
        },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}

EOF
}

resource "aws_lambda_function" "skuczynska-lambda" {
  filename         = "lambda.zip"
  function_name    = "skuczynska-lambda"
  role             = aws_iam_role.skuczynska-lambda-iam.arn
  handler          = "lambda.lambda_handler"
  source_code_hash = data.archive_file.lambda-zip.output_base64sha256
  runtime          = "python3.8"
}

resource "aws_apigatewayv2_api" "skuczynska-api" {
  name          = "skuczynska-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "skuczynska-api-stage" {
  api_id      = aws_apigatewayv2_api.skuczynska-api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "skuczynska-integration" {
  api_id               = aws_apigatewayv2_api.skuczynska-api.id
  integration_type     = "AWS_PROXY"
  integration_method   = "POST"
  integration_uri      = aws_lambda_function.skuczynska-lambda.invoke_arn
  passthrough_behavior = "WHEN_NO_MATCH"
}

resource "aws_apigatewayv2_route" "skuczynska-route" {
  api_id    = aws_apigatewayv2_api.skuczynska-api.id
  route_key = "GET /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.skuczynska-integration.id}"
}

resource "aws_lambda_permission" "skuczynska-api-gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.skuczynska-lambda.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.skuczynska-api.execution_arn}/*/*/*}"
}
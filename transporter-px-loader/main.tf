provider "aws" {
  region = "us-east-1"
  endpoints {
    s3 = "https://s3.us-east-1.amazonaws.com"
  }
}

#######################################################################################
# Create a S3 bucket to store the px-config files
# This bucket will be used by the transporter-px-lambda to download the px-config files
#######################################################################################
resource "aws_s3_bucket" "transporter-px-config-s3-bucket" {
  bucket = "${var.px-config-bucket-name}"
  acl    = "${var.px-config-bucket-acl}"
  tags = var.px-config-bucket-tags
}

#######################################################################################
# Create a Cloudwatch log group for the transporter-px-loader-lambda
# with 30 days retention period
#######################################################################################
resource "aws_cloudwatch_log_group" "transporter-px-loader-lambda-log-group" {
  name = "/aws/lambda/transporter-px-loader-lambda"
  retention_in_days = 30
}

#######################################################################################
# Create an IAM role for the transporter-px-loader-lambda
#######################################################################################
resource "aws_iam_role" "transporter_px_loader_lambda_role" {
  name = "transporter_px_loader_lambda_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

#######################################################################################
# Create an IAM policy for the transporter-px-loader-lambda
# This policy will allow the lambda function to read and write to the S3 bucket
# and write logs to Cloudwatch
# The policy also allows the lambda function to describe and update the MSK Connect 
# custom connector. The policy is attached to the IAM role created above
#######################################################################################
resource "aws_iam_policy" "transporter_px_loader_lambda_policy" {
  name = "transporter_px_loader_lambda_policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "${aws_s3_bucket.transporter-px-config-s3-bucket.arn}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kafkaconnect:DescribeConnector",
        "kafkaconnect:UpdateConnector"
      ],
      "Resource": ["*"]
    }
  ]
  
}
EOF
}

#######################################################################################
# Create a policy attachment to attach the IAM policy to the IAM role
# This will allow the lambda function to read and write to the S3 bucket
# and write logs to Cloudwatch
# The policy also allows the lambda function to describe and update the MSK Connect
# custom connector. The policy is attached to the IAM role created above
#######################################################################################
resource "aws_iam_role_policy_attachment" "transporter_px_loader_lambda_role_policy_attachment" {
  role       = aws_iam_role.transporter_px_loader_lambda_role.name
  policy_arn = aws_iam_policy.transporter_px_loader_lambda_policy.arn
}

##################################################################################################################################
# Create a Python3.12 based lambda function to load px-config changes for the Transporter MSK Connect custom connector. The lambda 
# function will be triggered by an S3 event when a new px-config file is created or uploaded. It will download all the the 
# px-config files from the S3 bucket /config folder and update the MSK Connect custom connector. It will write logs to Cloudwatch 
# log group transporter-px-loader-lambda. It will use the IAM role transporter_px_loader_lambda_role. The lambda function will use 
# the dummy lambda code zip stored in the S3 bucket lambda-dummy-code and will seed the lambda function with an init.txt file. 
# This is purposely done to keep the lambda function empty and to keep code deployment separate from infrastructure deployment. 
# To deploy python code to the lambda function, the code will be uploaded using an AWS CLI command after the terraform apply 
# command. The CLI command will look something like the following:
# aws lambda update-function-code --function-name transporter-px-loader-lambda --zip-file fileb://transporter-px-loader-lambda.zip
#
# Note: boto3 version 1.37.4 is required for this lambda function to work. The transporter-px-loader-lambda.zip file should
# contain the boto3 version 1.37.4 files and all its dependencies along with the transporter-px-loader-lambda.py file.
##################################################################################################################################
resource "aws_lambda_function" "app-transporter-px-loader-lambda" {
  role = aws_iam_role.transporter_px_loader_lambda_role.arn
  function_name = "transporter-px-loader-lambda"
  handler = "transporter-px-loader-lambda.event_handler"
  runtime = "python3.12"
  s3_bucket =  "${var.dummy-lambda-code-bucket-name}"
  s3_key = "${var.dummy-lambda-code-zip}"
  description = "Lambda function to load and transporter px-config changes into the MSK Connect custom connector"
}

#######################################################################################
# Create a lambda permission to allow the px-config S3 bucket to invoke the transporter
# px config lambda function when a new config file is created or uploaded
#######################################################################################
resource "aws_lambda_permission" "allow_s3_to_invoke_lambda" {
  statement_id = "AllowExecutionFromS3"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.app-transporter-px-loader-lambda.function_name
  principal = "s3.amazonaws.com"
  source_arn = aws_s3_bucket.transporter-px-config-s3-bucket.arn
}

#######################################################################################
# Create a S3 bucket notification to trigger the transporter px config lambda function
# when a new px-config file is created or uploaded to the S3 bucket /config folder
#######################################################################################
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.transporter-px-config-s3-bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.app-transporter-px-loader-lambda.arn
    events = ["s3:ObjectCreated:*"]
    filter_prefix = "config/"
  }
}

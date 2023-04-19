provider "aws" {
    region = "us-east-1"
}
provider "archive" {}
data "archive_file" "zip" {
    type        = "zip"
    source_dir  = "C:\\Users\\MyyaB\\OneDrive\\Desktop\\proj3\\to_aws.zip"
    output_path = "index.zip"
}

#lambda function creation
resource "aws_lambda_function" "lambda" {
    function_name           = "tdc_lambda"
    filename                = data.archive_file.zip.output_path
    role                    = "${aws_iam_role.lambda-exec.arn}"
    handler                 = "index.handler"
    runtime                 = "nodejs18.x"

    vpc_config {
      subnet_ids         = [ "subnet-05ecb5cf1a52f75fd", "subnet-05687a9be3ac0c150" ]
      security_group_ids = [ "sg-0179a6c0ad02bf95d", "sg-065dd0f152d020822" ]
    }
}

resource "aws_iam_role" "lambda-exec" {
    name = "tdc_lambda_role"
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

resource "aws_iam_policy" "iam_policy_for_lambda" {
 
 name         = "aws_iam_policy_for_terraform_aws_lambda_role"
 path         = "/"
 description  = "AWS IAM Policy for managing aws lambda role"
 policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
 role        = aws_iam_role.lambda-exec.id
 policy_arn  = aws_iam_policy.iam_policy_for_lambda.arn
}

resource "aws_iam_role_policy_attachment" "iam_policy_for_vpc" {
  role       = aws_iam_role.lambda-exec.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
  
}

resource "aws_iam_policy" "iam_for_rds" {
 name         = "aws_iam_policy_for_rds"
 path         = "/"
 description  = "AWS IAM Policy for full access to RDS"
 policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "rds:*",
                "application-autoscaling:DeleteScalingPolicy",
                "application-autoscaling:DeregisterScalableTarget",
                "application-autoscaling:DescribeScalableTargets",
                "application-autoscaling:DescribeScalingActivities",
                "application-autoscaling:DescribeScalingPolicies",
                "application-autoscaling:PutScalingPolicy",
                "application-autoscaling:RegisterScalableTarget",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:DeleteAlarms",
                "cloudwatch:ListMetrics",
                "cloudwatch:GetMetricData",
                "ec2:DescribeAccountAttributes",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeCoipPools",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeLocalGatewayRouteTablePermissions",
                "ec2:DescribeLocalGatewayRouteTables",
                "ec2:DescribeLocalGatewayRouteTableVpcAssociations",
                "ec2:DescribeLocalGateways",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSubnets",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcs",
                "ec2:GetCoipPoolUsage",
                "sns:ListSubscriptions",
                "sns:ListTopics",
                "sns:Publish",
                "logs:DescribeLogStreams",
                "logs:GetLogEvents",
                "outposts:GetOutpostInstanceTypes",
                "devops-guru:GetResourceCollection"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "pi:*",
            "Resource": "arn:aws:pi:*:*:metrics/rds/*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "iam:AWSServiceName": [
                        "rds.amazonaws.com",
                        "rds.application-autoscaling.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Action": [
                "devops-guru:SearchInsights",
                "devops-guru:ListAnomaliesForInsight"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Condition": {
                "ForAllValues:StringEquals": {
                    "devops-guru:ServiceNames": [
                        "RDS"
                    ]
                },
                "Null": {
                    "devops-guru:ServiceNames": "false"
                }
            }
        }
    ]
  }
EOF
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_for_rds" {
  role       = aws_iam_role.lambda-exec.id
  policy_arn = aws_iam_policy.iam_for_rds.arn
}

resource "aws_api_gateway_rest_api" "rest_api" {
    name        = "tdc_rest_api"
    endpoint_configuration {
      types = ["REGIONAL"]
    }
    description = "Rest API for lambda invocation"
}

resource "aws_api_gateway_resource" "test_api" {
    rest_api_id     = "${aws_api_gateway_rest_api.rest_api.id}"
    parent_id       = "${aws_api_gateway_rest_api.rest_api.root_resource_id}"
    path_part       = "${aws_api_gateway_rest_api.rest_api.root_resource_id}"
}

resource "aws_api_gateway_method" "get_method" {
    rest_api_id   = "${aws_api_gateway_rest_api.rest_api.id}"
    resource_id   = "${aws_api_gateway_resource.test_api.id}"
    http_method   = "GET"
    authorization = "NONE"
}

resource "aws_api_gateway_method_response" "get_response" {
  rest_api_id = "${aws_api_gateway_rest_api.rest_api.id}"
  resource_id = "${aws_api_gateway_resource.test_api.id}"
  http_method = "${aws_api_gateway_method.get_method.http_method}"
  status_code = "200"

}

resource "aws_api_gateway_integration" "lambda" {
    rest_api_id = "${aws_api_gateway_rest_api.rest_api.id}"
    resource_id = "${aws_api_gateway_resource.test_api.id}"
    http_method = "${aws_api_gateway_method.get_method.http_method}"

    integration_http_method = "${aws_api_gateway_method.get_method.http_method}"
    type                    = "AWS"
    uri                     = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda.arn}/invocations"

}

resource "aws_api_gateway_integration_response" "dummy_integration_response" {
  rest_api_id = "${aws_api_gateway_rest_api.rest_api.id}"
  resource_id = "${aws_api_gateway_rest_api.rest_api.root_resource_id}"
  http_method = "${aws_api_gateway_method.get_method.http_method}"
  status_code = "${aws_api_gateway_method_response.get_response.status_code}"
  depends_on  = [aws_api_gateway_integration.lambda]

}

resource "aws_lambda_permission" "allow_api_gateway" {
    function_name = "${aws_lambda_function.lambda.id}"
    statement_id = "AllowExecutionFromApiGateway"
    action = "lambda:InvokeFunction"
    principal = "apigateway.amazonaws.com"
    source_arn =  "${aws_api_gateway_rest_api.rest_api.execution_arn}/*"
}

resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  triggers = {
    # NOTE: The configuration below will satisfy ordering considerations,
    #       but not pick up all future REST API changes. More advanced patterns
    #       are possible, such as using the filesha1() function against the
    #       Terraform configuration file(s) or removing the .id references to
    #       calculate a hash against whole resources. Be aware that using whole
    #       resources will show a difference after the initial implementation.
    #       It will stabilize to only change when resources change afterwards.
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.test_api.id,
      aws_api_gateway_method.get_method.id,
      aws_api_gateway_integration.lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "staging" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "staging"
}
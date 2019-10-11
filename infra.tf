terraform {
  backend "s3" {}
}

variable "serverless_bucket_name" {
  description = "The bucket into which Serverless will deploy the app."
}

variable "app_account_name" {
  description = "The name to assign to the IAM user under which the API will run."
}

variable "domain_path" {
  description = "The DNS path to affix to the domain_tld."
}

variable "domain_tld" {
  description = "The domain name to use; this is used for creating HTTPS certificates."
}

resource "aws_s3_bucket" "serverless_bucket" {
  bucket = "${var.serverless_bucket_name}"
}

resource "aws_iam_user" "app" {
  name = "slack_api_app_account"
}

resource "aws_iam_access_key" "app" {
  user = "${aws_iam_user.app.name}"
}

resource "aws_iam_user_policy" "app" {
  name = "slack_api_app_account_policy"
  user = "${aws_iam_user.app.name}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
     {
        "Action": ["s3:ListObjects"],
        "Effect": "Allow",
        "Resource": "*"
     }
  ]
}
EOF
}

resource "aws_acm_certificate" "app_cert" {
  domain_name = "${var.domain_path}.${var.domain_tld}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

output "app_account_ak" {
  value = "${aws_iam_access_key.app.id}"
}

output "app_account_sk" {
  value = "${aws_iam_access_key.app.secret}"
}

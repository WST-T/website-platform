# terraform config
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

# aws config
provider "aws" {
  region = "us-east-1"
}

# Variables
variable "ssh_key_name" {
  description = "Name of the SSH key pair to use for EC2 instance"
  type        = string
  default     = "websites-platform-key"
}

variable "create_key_pair" {
  description = "Whether to create a key pair"
  type        = bool
  default     = true
}

# Create a new key pair if needed
resource "aws_key_pair" "deployer" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.ssh_key_name
  public_key = file("~/.ssh/id_rsa.pub")

  # If you don't have a key, use this to output the private key to a file
  # provisioner "local-exec" {
  #   command = "echo '${tls_private_key.example[0].private_key_pem}' > ./private_key.pem && chmod 600 ./private_key.pem"
  # }
}

# Security Group for EC2
resource "aws_security_group" "api_sg" {
  name        = "api-server-sg"
  description = "Security group for API server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance for API
resource "aws_instance" "api_server" {
  ami                    = "ami-0440d3b780d96b29d" # Amazon Linux 2 AMI (adjust as needed)
  instance_type          = "t2.micro"
  key_name               = var.create_key_pair ? aws_key_pair.deployer[0].key_name : var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.api_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker git
              systemctl start docker
              systemctl enable docker
              curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              mkdir -p /app
              cd /app
              git clone https://github.com/user/websites-platform.git .
              docker-compose up api -d
              EOF

  tags = {
    Name = "api-server"
  }
}

# S3 bucket for website static files
resource "aws_s3_bucket" "website_bucket" {
  bucket = "website-platform-static-files-${random_string.bucket_suffix.result}"

  # This is important - force destroy allows Terraform to delete non-empty buckets
  force_destroy = true
}

# Generate random suffix for S3 bucket name
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket_ownership_controls" "website_bucket_ownership" {
  bucket = aws_s3_bucket.website_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# This sets public access settings at bucket level
resource "aws_s3_bucket_public_access_block" "website_bucket_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "website_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.website_bucket_ownership,
    aws_s3_bucket_public_access_block.website_bucket_access,
  ]

  bucket = aws_s3_bucket.website_bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Delay policy to ensure public access block has propagated
resource "time_sleep" "wait_for_public_access_block" {
  depends_on = [aws_s3_bucket_public_access_block.website_bucket_access]

  create_duration = "10s"
}

# Now add the bucket policy after ensuring public access is allowed
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  depends_on = [time_sleep.wait_for_public_access_block]

  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      },
    ]
  })
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.website_config.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.website_bucket.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_image_downloader_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda
resource "aws_iam_policy" "lambda_policy" {
  name        = "lambda_image_downloader_policy"
  description = "Policy for Lambda function to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.website_bucket.arn,
          "${aws_s3_bucket.website_bucket.arn}/*"
        ]
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# Lambda function for image downloading
resource "aws_lambda_function" "image_downloader" {
  filename      = "image_downloader.zip"
  function_name = "image_downloader"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_handler.handler"
  runtime       = "python3.9"
  timeout       = 60

  environment {
    variables = {
      API_ENDPOINT = "http://${aws_instance.api_server.public_ip}:3000",
      S3_BUCKET    = aws_s3_bucket.website_bucket.id
    }
  }
}

# CloudWatch Event Rule to trigger Lambda daily
resource "aws_cloudwatch_event_rule" "daily_image_download" {
  name                = "daily-image-download"
  description         = "Triggers the image downloader Lambda function daily"
  schedule_expression = "rate(1 day)"
}

# Connect the CloudWatch Event to the Lambda function
resource "aws_cloudwatch_event_target" "image_download_target" {
  rule      = aws_cloudwatch_event_rule.daily_image_download.name
  target_id = "ImageDownloaderLambda"
  arn       = aws_lambda_function.image_downloader.arn
}

# Allow CloudWatch Events to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_downloader.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_image_download.arn
}

# Outputs
output "api_server_public_ip" {
  description = "Public IP address of the API server"
  value       = aws_instance.api_server.public_ip
}

output "website_url" {
  description = "CloudFront website URL"
  value       = "https://${aws_cloudfront_distribution.website_distribution.domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.website_bucket.id
}

output "s3_website_endpoint" {
  description = "S3 website endpoint"
  value       = aws_s3_bucket_website_configuration.website_config.website_endpoint
}
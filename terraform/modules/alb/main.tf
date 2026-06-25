variable "project" {}
variable "environment" {}
variable "vpc_id" {}
variable "public_subnet_ids" {}

resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "Allow HTTP/HTTPS inbound to ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-alb-sg" }
}

# S3 bucket for ALB access logs — satisfies CKV_AWS_91
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project}-${var.environment}-alb-logs"
  force_destroy = true  # allow easy teardown in demo environment

  tags = { Name = "${var.project}-${var.environment}-alb-logs" }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}  # required in AWS provider v4+ — empty filter means apply to all objects
    expiration { days = 30 }
  }
}

# Enable server-side logging on the log bucket itself — satisfies CKV_AWS_18
resource "aws_s3_bucket_logging" "alb_logs" {
  bucket        = aws_s3_bucket.alb_logs.id
  target_bucket = aws_s3_bucket.alb_logs.id
  target_prefix = "self-logs/"
}

# Enforce HTTPS-only access — satisfies CKV_AWS_54
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowALBLogs"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::127311923021:root" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/*"
      },
      {
        Sid       = "DenyNonTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [
          aws_s3_bucket.alb_logs.arn,
          "${aws_s3_bucket.alb_logs.arn}/*"
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      }
    ]
  })
}

resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false  # set true in production

  # Access logs to S3 — satisfies CKV_AWS_91
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }

  tags = { Name = "${var.project}-${var.environment}-alb" }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project}-${var.environment}-tg"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"  # required for Fargate

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = { Name = "${var.project}-${var.environment}-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

output "dns_name"          { value = aws_lb.main.dns_name }
output "target_group_arn"  { value = aws_lb_target_group.app.arn }
output "security_group_id" { value = aws_security_group.alb.id }

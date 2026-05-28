resource "aws_s3_bucket" "lab" {
  bucket = var.bucket_name

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_dynamodb_table" "lab" {
  name         = "pipeline-lab-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

# --- NETWORKING ---

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_security_group" "platform" {
  vpc_id      = aws_vpc.main.id
  description = "FedRAMP-adjacent platform security group"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.s3"
  vpc_endpoint_type = "Gateway"

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.dynamodb"
  vpc_endpoint_type = "Gateway"

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

# --- ENCRYPTION ---

resource "aws_kms_key" "platform" {
  description             = "Platform encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_kms_alias" "platform" {
  name          = "alias/pipeline-lab-platform"
  target_key_id = aws_kms_key.platform.key_id
}

# --- IAM ---

resource "aws_iam_role" "platform_app" {
  name = "pipeline-lab-platform-app"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  permissions_boundary = aws_iam_policy.boundary.arn

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_iam_policy" "boundary" {
  name        = "pipeline-lab-permission-boundary"
  description = "Permission boundary for platform application role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_iam_role_policy" "platform_app_inline" {
  name = "pipeline-lab-platform-app-policy"
  role = aws_iam_role.platform_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- AUDIT ---

resource "aws_s3_bucket" "audit_logs" {
  bucket = "pipeline-lab-audit-logs"

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}

resource "aws_s3_bucket_versioning" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "audit_logs" {
  bucket = aws_s3_bucket.audit_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudtrail" "platform" {
  name                          = "pipeline-lab-trail"
  s3_bucket_name                = aws_s3_bucket.audit_logs.id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_versioning.audit_logs]

  tags = {
    Environment         = "local"
    ManagedBy           = "terraform"
    Project             = "pipeline-lab"
    ComplianceFramework = "FedRAMP-adjacent"
  }
}
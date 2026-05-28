output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.lab.bucket
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.lab.arn
}

output "dynamodb_table_name" {
  description = "Name of the created DynamoDB table"
  value       = aws_dynamodb_table.lab.name
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "kms_key_arn" {
  description = "ARN of the platform KMS key"
  value       = aws_kms_key.platform.arn
}

output "platform_role_arn" {
  description = "ARN of the platform application IAM role"
  value       = aws_iam_role.platform_app.arn
}

output "audit_bucket_name" {
  description = "Name of the audit logs S3 bucket"
  value       = aws_s3_bucket.audit_logs.bucket
}

output "cloudtrail_name" {
  description = "Name of the CloudTrail trail"
  value       = aws_cloudtrail.platform.name
}
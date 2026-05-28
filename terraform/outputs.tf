output "bucket_name" {
  description = "Name of the created S3 bucket"
  value       = aws_s3_bucket.lab.bucket
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.lab.arn
}
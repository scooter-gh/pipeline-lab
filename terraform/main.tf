resource "aws_s3_bucket" "lab" {
  bucket = var.bucket_name

  tags = {
    Environment = "local"
    ManagedBy   = "terraform"
    Project     = "pipeline-lab"
  }
}
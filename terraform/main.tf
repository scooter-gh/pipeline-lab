resource "aws_s3_bucket" "lab" {
  bucket = var.bucket_name

  tags = {
    Environment = "local"
    ManagedBy   = "terraform"
    Project     = "pipeline-lab"
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
    Environment = "local"
    ManagedBy   = "terraform"
    Project     = "pipeline-lab"
  }
}
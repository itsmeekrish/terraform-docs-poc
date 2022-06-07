resource "aws_s3_bucket" "poc_dark_artifact" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_acl" "poc_dark_artifact_acl" {
  bucket = aws_s3_bucket.poc_dark_artifact.id
  acl    = "private"
}
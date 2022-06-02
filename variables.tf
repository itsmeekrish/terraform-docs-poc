variable "GITHUB_PERSONAL_TOKEN" {
  type    = string
  description = "Github personal access token"
  default = ""
}

variable "bucket_name" {
    type = string
    description = "Name of the S3 bucket"
    default = "poc-codebuild-artifact"
}
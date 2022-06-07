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

variable "iam_role" {
    type = string
    description = "IAM role name for the code build resource"
    default = "codebuild_role"
}

variable "codebuild_project_name" {
    type = string
    description = "Name of the code build project"
    default = "poc-codebuild"
}
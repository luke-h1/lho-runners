variable "env" {
  description = "Environment name, used as prefix"
  type        = string
  default     = "test"
  validation {
    condition     = contains(["test", "production"], var.env)
    error_message = "env must be either 'test' or 'production'"
  }
}

variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "eu-west-2"
  validation {
    condition     = contains(["eu-west-2"], var.aws_region)
    error_message = "aws_region must be IRE"
  }
}

variable "github_app_private_key" {
  description = "The base64 encoded string of the GitHub app PEM"
  type        = string
}

variable "github_app_id" {
  description = "The ID of the GitHub app"
  type        = string
}

variable "github_app_webhook_secret" {
  description = "GitHub app webhook secret."
  type        = string
}

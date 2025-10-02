variable "prefix" {
  description = "Prefix used for resource naming."
  type        = string
  default     = "test"
}

variable "aws_region" {
  description = "AWS region to create the VPC, assuming zones `a` and `b` exists."
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name for resource tagging."
  type        = string
  default     = "test"
}

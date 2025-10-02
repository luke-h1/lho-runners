# Data source to get the base VPC outputs
data "terraform_remote_state" "base" {
  backend = "s3"
  config = {
    bucket = "lho-gh-runners-${var.env}-terraform-state"
    key    = "vpc/${var.env}.tfstate"
    region = var.region
  }
}

output "packer_variables" {
  description = "Variables to pass to Packer build"
  value = {
    region                      = var.region
    subnet_id                   = data.terraform_remote_state.base.outputs.vpc.public_subnets[0]
    security_group_id           = data.terraform_remote_state.base.outputs.vpc.default_security_group_id
    associate_public_ip_address = "true"
  }
}

resource "local_file" "packer_vars" {
  content = jsonencode({
    region                      = var.region
    subnet_id                   = data.terraform_remote_state.base.outputs.vpc.public_subnets[0]
    security_group_id           = data.terraform_remote_state.base.outputs.vpc.default_security_group_id
    associate_public_ip_address = "true"
  })
  filename = "${path.module}/packer-vars.json"
}

# Variables needed
variable "env" {
  description = "Environment name"
  type        = string
  default     = "test"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
} 
data "terraform_remote_state" "vpc" {
  backend   = "s3"
  workspace = var.env
  config = {
    bucket  = "lho-gh-runners-${var.env}-terraform-state"
    key     = "vpc/${var.env}.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}

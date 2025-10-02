terraform {
  backend "s3" {
  }
}

provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = {
      created_by = "terraform"
      managed_by = "terraform"
      project    = "github-runners"
    }
  }
}

provider "aws" {
  alias  = "terraform_role"
  region = "eu-west-2"

  default_tags {
    tags = {
      created_by = "terraform"
      managed_by = "terraform"
      project    = "github-runners"
    }
  }
}

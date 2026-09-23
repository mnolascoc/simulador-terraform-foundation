provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = var.terraform_role_arn # rol terraform-deploy de la cuenta Non-Prod
  }

  default_tags {
    tags = {
      Project     = "simulador"
      Environment = "nonprod"
      ManagedBy   = "terraform"
      Repository  = "simulador-terraform-foundation"
    }
  }
}

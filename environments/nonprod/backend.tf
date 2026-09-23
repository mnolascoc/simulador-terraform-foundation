terraform {
  required_version = ">= 1.9.0"

  backend "s3" {
    bucket         = "simulator-terraform-deploy-mnc"
    key            = "foundation/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform_locks_nonprod"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "simulador"
      Environment = "nonprod"
      ManagedBy   = "terraform"
      Repository  = "simulador-terraform-foundation"
    }
  }
}

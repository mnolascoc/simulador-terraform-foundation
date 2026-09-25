module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  environment          = "nonprod"
}

# module "vpc_endpoints" {
#   source = "../../modules/vpc-endpoints"
#
#   aws_region              = var.aws_region
#   vpc_id                  = module.vpc.vpc_id
#   private_route_table_ids = module.vpc.private_route_table_ids
#   environment             = "nonprod"
#
#   # Deshabilitado: las tasks de ECS corren en subnet pública
#   # (assign_public_ip) y salen directo por el IGW. El módulo solo crea
#   # Gateway endpoints (S3, DynamoDB) — no hay Interface endpoints (se
#   # eliminaron del módulo al no usarse subnet privada). Reactivar si en
#   # el futuro algo en subnet privada necesita hablar con S3/DynamoDB sin
#   # pasar por NAT.
# }

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  vpc_id       = module.vpc.vpc_id
  cluster_name = "simulator-nonprod" # compartido entre dev y uat
  environment  = "nonprod"
}

# Bucket de artifacts Lambda (compartido dev/uat)
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "simulator-lambda-artifacts-mnc"
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  rule {
    id     = "expire-old-artifacts"
    status = "Enabled"
    filter {}
    expiration { days = 90 }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

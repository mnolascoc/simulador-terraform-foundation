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

#   aws_region              = var.aws_region
#   vpc_id                  = module.vpc.vpc_id
#   vpc_cidr                = var.vpc_cidr
#   private_subnet_ids      = module.vpc.private_subnet_ids
#   private_route_table_ids = module.vpc.private_route_table_ids
#   environment             = "nonprod"

#   # Sin interface endpoints por ahora: las tasks de ECS corren en subnet
#   # pública (assign_public_ip) y salen directo por el IGW, así que ECR y
#   # Textract no necesitan endpoint (evita el costo fijo por hora + GB de
#   # cada Interface endpoint). Si en el futuro las tasks pasan a subnet
#   # privada, agregar aquí interface_endpoint_services = ["ecr.api", "ecr.dkr", "textract"].
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

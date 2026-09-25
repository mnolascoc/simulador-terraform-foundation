resource "aws_ecs_cluster" "this" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name = var.cluster_name
  }
}

# Fargate (on-demand) y Fargate Spot disponibles como capacity providers.
# El peso por defecto favorece Spot para cargas tolerantes a interrupción
# (razonable para el motor de extracción en dev/uat); en prod se recomienda
# pasar default_capacity_provider_weight_spot = 0 vía tfvars si el motor de
# extracción en producción no debe correr en instancias Spot.
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = var.default_capacity_provider_weight_fargate
    base              = 1
  }

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.default_capacity_provider_weight_spot
  }
}

# SG para las tasks del cluster. Se invocan vía RunTask desde una Lambda
# (no reciben tráfico de red entrante), por lo que no hay reglas de
# ingress: solo egress para que puedan llamar a ECR, Textract, S3, etc.
resource "aws_security_group" "tasks" {
  name        = "${var.cluster_name}-tasks-sg"
  description = "SG para tasks ECS del cluster ${var.cluster_name}: sin ingress (se invocan via RunTask, no por red), egress abierto para dependencias externas (ECR, Textract, S3, etc.)"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-tasks-sg"
  }
}

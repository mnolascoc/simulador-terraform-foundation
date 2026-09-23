# Gateway endpoints (S3, DynamoDB): sin costo por hora ni por GB procesado,
# se agregan siempre. Reducen tráfico que de otro modo pasaría por el NAT
# Gateway (y su costo de procesamiento por GB), sin trade-off alguno.

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = {
    Name = "simulador-${var.environment}-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.private_route_table_ids

  tags = {
    Name = "simulador-${var.environment}-dynamodb-endpoint"
  }
}

# Interface endpoints (ECR, Secrets Manager, etc.): SÍ tienen costo por hora
# + por GB procesado (similar a un NAT pequeño), por eso son opcionales y
# parametrizados vía var.interface_endpoint_services. Útiles si las tasks de
# ECS (extracción) o Lambdas en subnet privada necesitan hablar con esos
# servicios y se quiere evaluar prescindir del NAT Gateway para ese tráfico
# específico — evaluar costo-beneficio antes de habilitar cada uno.

resource "aws_security_group" "interface_endpoints" {
  count       = length(var.interface_endpoint_services) > 0 ? 1 : 0
  name        = "simulador-${var.environment}-vpce-sg"
  description = "Permite HTTPS desde la VPC hacia los interface endpoints"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "simulador-${var.environment}-vpce-sg"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each            = toset(var.interface_endpoint_services)
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.interface_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "simulador-${var.environment}-${each.value}-endpoint"
  }
}

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

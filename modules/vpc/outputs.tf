output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}

# Lista de route tables privadas (una por AZ) — el módulo nat-gateway
# necesita esto para insertar la ruta 0.0.0.0/0 hacia el NAT Gateway.
output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.this.id
}

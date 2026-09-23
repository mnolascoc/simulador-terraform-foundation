variable "environment" {
  type        = string
  description = "Nombre del ambiente (dev, uat, prod). Se usa como sufijo en el naming de todos los recursos de este módulo."
}

variable "vpc_cidr" {
  type        = string
  description = "Bloque CIDR de la VPC (ej. 10.10.0.0/16 para nonprod, 10.20.0.0/16 para prod). Usar rangos no solapados entre cuentas si se prevé VPC peering futuro."
}

variable "availability_zones" {
  type        = list(string)
  description = "Lista de AZs a usar, en el mismo orden que public_subnet_cidrs y private_subnet_cidrs (el índice N de cada lista corresponde a la misma AZ)."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Bloques CIDR de las subnets públicas, uno por AZ, mismo orden que availability_zones."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Bloques CIDR de las subnets privadas, uno por AZ, mismo orden que availability_zones."
}

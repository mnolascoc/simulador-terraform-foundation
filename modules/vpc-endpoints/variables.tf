variable "environment" {
  type        = string
  description = "Nombre del ambiente (nonprod, prod). Se usa como sufijo en el naming de los recursos de este módulo."
}

variable "aws_region" {
  type        = string
  description = "Región AWS donde se crean los endpoints (debe coincidir con la región del provider raíz)."
}

variable "vpc_id" {
  type        = string
  description = "ID de la VPC donde se crean los endpoints (output vpc_id del módulo vpc)."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR de la VPC, usado para restringir el ingress del security group de interface endpoints al tráfico interno."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "IDs de las subnets privadas donde se despliegan las interfaces de red de los Interface endpoints (output private_subnet_ids del módulo vpc)."
}

variable "private_route_table_ids" {
  type        = list(string)
  description = "IDs de las route tables privadas asociadas a los Gateway endpoints (S3, DynamoDB)."
}

variable "interface_endpoint_services" {
  type        = list(string)
  description = "Nombres cortos de servicios AWS (ej. \"ecr.api\", \"ecr.dkr\", \"secretsmanager\", \"bedrock-runtime\") para los que crear Interface endpoints. Lista vacía por defecto: no se crea ninguno hasta que se identifique una necesidad concreta de evitar salida por NAT para ese servicio."
  default     = []
}

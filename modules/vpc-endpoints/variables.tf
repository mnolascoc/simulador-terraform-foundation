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

variable "private_route_table_ids" {
  type        = list(string)
  description = "IDs de las route tables privadas asociadas a los Gateway endpoints (S3, DynamoDB)."
}

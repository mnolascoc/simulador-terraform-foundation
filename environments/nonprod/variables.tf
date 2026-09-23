variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "terraform_role_arn" {
  type        = string
  description = <<-EOT
    ARN del rol IAM que Terraform asume (vía assume_role) para aprovisionar
    recursos en esta cuenta AWS. Debe ser el rol "terraform-deploy" creado
    en la Fase 1 (OIDC), cuyo trust policy restringe qué repo/branch de
    GitHub Actions puede asumirlo.

    - nonprod/terraform.tfvars -> rol de la cuenta Non-Prod
    - prod/terraform.tfvars    -> rol de la cuenta Prod

    Este valor NO es secreto en sí mismo (un ARN no otorga acceso sin la
    cadena de autenticación OIDC completa), pero se mantiene como variable
    parametrizada -en vez de hardcodeado en provider.tf- para que el mismo
    main.tf funcione sin cambios entre ambientes, y para evitar reescribir
    el ARN si el rol se recrea con otro nombre.
  EOT
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "availability_zones" {
  type = list(string)
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

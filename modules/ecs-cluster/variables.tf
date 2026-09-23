variable "vpc_id" {
  type        = string
  description = "ID de la VPC donde corren las tasks del cluster (output vpc_id del módulo vpc). Se usa para crear el security group de las tasks."
}

variable "cluster_name" {
  type        = string
  description = "Nombre del cluster ECS (ej. \"simulador-nonprod\" compartido entre dev/uat, o \"simulador-prod\")."
}

variable "environment" {
  type        = string
  description = "Nombre del ambiente (nonprod, prod). Se usa para tagging; el cluster puede ser compartido por varios ambientes lógicos dentro de la misma cuenta (dev/uat)."
}

variable "enable_container_insights" {
  type        = bool
  description = "Habilita CloudWatch Container Insights para métricas detalladas por task/servicio. Tiene costo adicional de CloudWatch; deshabilitar en ambientes de muy bajo presupuesto si no se necesita observabilidad granular."
  default     = true
}

variable "default_capacity_provider_weight_fargate" {
  type        = number
  description = "Peso relativo de FARGATE (on-demand) en la estrategia de capacidad por defecto del cluster."
  default     = 1
}

variable "default_capacity_provider_weight_spot" {
  type        = number
  description = "Peso relativo de FARGATE_SPOT en la estrategia de capacidad por defecto. Usar 0 en prod si el motor de extracción no debe tolerar interrupciones por reclamo de capacidad Spot."
  default     = 3
}

# poc-account-foundation

Infraestructura como código (Terraform) para la base de cuenta AWS del proyecto **simulador**: motor de extracción que corre como ECS task Fargate, invocado bajo demanda (`RunTask`) desde una Lambda.

## Ambientes

| Ambiente | Estado | Cuenta AWS | Uso |
|---|---|---|---|
| `environments/nonprod` | Implementado | Non-Prod (compartida) | dev + uat, mismo cluster ECS y mismo bucket de artifacts |
| `environments/prod` | Pendiente | Prod | Aún no creado |

Cada ambiente asume un rol IAM (`terraform-deploy`) vía OIDC — pensado para ejecutarse desde GitHub Actions, sin credenciales estáticas. El state se guarda en S3 (`simulator-terraform-deploy-mnc`) con locking en DynamoDB (`terraform_locks_nonprod`).

## Recursos que se habilitan (`nonprod`)

### Red — módulo `modules/vpc`

| Recurso | Descripción |
|---|---|
| `aws_vpc.this` | VPC dedicada del ambiente (`10.0.0.0/16` en noprod), con DNS support/hostnames habilitado. |
| `aws_internet_gateway.this` | Salida/entrada a internet para las subnets públicas. |
| `aws_subnet.public` (x2) | Una por AZ (`us-east-1a`, `us-east-1b`), `map_public_ip_on_launch = true`. Aquí corren las tasks de ECS. |
| `aws_subnet.private` (x2) | Una por AZ. Hoy sin salida a internet (no hay NAT Gateway desplegado) — solo sirven para recursos que no necesiten internet o que usen VPC endpoints. |
| `aws_route_table.public` + asociaciones | Ruta `0.0.0.0/0 → IGW`, asociada a ambas subnets públicas. |
| `aws_route_table.private` (x2) + asociaciones | Una route table privada **por AZ** (no compartida), a propósito: permite apuntar cada una a su propio NAT Gateway el día que se agregue, en vez de forzar un NAT compartido entre AZs. |

**Buena práctica aplicada:** separar route tables públicas/privadas y, dentro de privadas, una por AZ, evita tener que re-cablear el routing si más adelante se decide alta disponibilidad de NAT (uno por AZ) en vez de uno compartido.

### VPC Endpoints — módulo `modules/vpc-endpoints` (creado, **actualmente deshabilitado**)

El módulo solo crea Gateway endpoints (S3, DynamoDB) — sin costo por hora ni por GB, sin trade-off. Los Interface endpoints (ECR, Textract, etc.) se eliminaron del módulo: al correr la ECS task en subnet pública con salida directa por el IGW, no aportarían nada sobre ese camino ya gratuito, y sí tendrían costo fijo por hora + por GB.

Su invocación está comentada en `environments/nonprod/main.tf`. Reactivar solo si en el futuro algún recurso en subnet privada necesita hablar con S3/DynamoDB sin pasar por NAT.

### ECS — módulo `modules/ecs-cluster`

| Recurso | Descripción |
|---|---|
| `aws_ecs_cluster.this` | Cluster `simulator-nonprod`, compartido entre dev y uat. Container Insights habilitado por defecto (costo adicional de CloudWatch; desactivable vía `enable_container_insights = false` si el presupuesto es muy ajustado). |
| `aws_ecs_cluster_capacity_providers.this` | Fargate + Fargate Spot. Peso por defecto favorece Spot (`weight = 3` vs `1`) — razonable para el motor de extracción en dev/uat, que tolera interrupciones. **En prod**, pasar `default_capacity_provider_weight_spot = 0` vía tfvars si el motor de extracción no debe correr en instancias Spot. |
| `aws_security_group.tasks` | SG de las tasks del cluster. **Sin reglas de ingress**: la task se invoca vía `RunTask` desde la Lambda (llamada a la API de ECS, no tráfico de red hacia el container), por lo que no necesita recibir conexiones entrantes. Egress abierto (`0.0.0.0/0`) para que pueda llamar a ECR, Textract, S3, etc. |

**Buena práctica aplicada:** el SG sigue el principio de mínimo privilegio en la dirección que importa — cero ingress porque no hay ningún flujo legítimo que lo necesite. Egress amplio es una concesión consciente (no hay endpoints privados activos hoy); si se restringe más adelante, podría acotarse a los rangos de IP de los servicios AWS usados.

### Almacenamiento — `environments/nonprod/main.tf` (recursos sueltos, no modularizados)

| Recurso | Descripción |
|---|---|
| `aws_s3_bucket.lambda_artifacts` | Bucket compartido dev/uat para artifacts de Lambda. |
| `aws_s3_bucket_versioning.lambda_artifacts` | Versionado habilitado — permite recuperar una versión anterior de un artifact ante un deploy fallido. |
| `aws_s3_bucket_lifecycle_configuration.lambda_artifacts` | Expira artifacts no vigentes a los 90 días y versiones no-actuales a los 30 días, para no acumular costo de almacenamiento indefinidamente. |

## Puntos importantes / decisiones de diseño

- **ECS task con IP pública, sin ALB de por medio.** Al no haber NAT Gateway ni Interface Endpoints (removidos del módulo), las tasks necesitan `assign_public_ip = true` en su `network_configuration` para poder llamar a ECR/Textract/S3 vía el IGW. Esto expone la ENI de la task con una IP pública, pero **no representa un riesgo de acceso entrante** mientras el SG (`aws_security_group.tasks`) no tenga reglas de ingress: nadie puede iniciar una conexión hacia el container desde internet, solo la task puede iniciar conexiones salientes. El único canal de invocación es la API de ECS (`RunTask`) desde la Lambda, autorizado por IAM — no por red.
  - Si en algún momento la task pasa a exponer un puerto (por ejemplo, para health checks o una API interna), **revisar esta decisión**: en ese caso sí conviene subnet privada + NAT/VPC endpoints, o un ALB delante, para no depender de "SG sin ingress" como única barrera.
- **Sin NAT Gateway.** Decisión de costo para etapa temprana de startup: un NAT Gateway cuesta ~$32-38/mes fijos + procesamiento por GB, por AZ. Al día de hoy nada en subnet privada necesita salir a internet, así que no se justifica.
- **Cluster y bucket de artifacts compartidos entre dev y uat** dentro de la cuenta non-prod, para reducir superficie de recursos a mantener y costo — aceptable porque son ambientes de bajo tráfico y no productivos. Prod, cuando se implemente, va en cuenta separada (aislamiento total de datos/red respecto a non-prod).
- **Fargate Spot como default en non-prod**, no en prod — ver tabla de ECS arriba.
- **`terraform_role_arn` parametrizado por tfvars**, no hardcodeado en `provider.tf`, para que el mismo `main.tf`/`provider.tf` funcione sin cambios entre ambientes (solo cambia el tfvars).
- **Pendiente de definir** (fuera del alcance actual de este repo): la task definition de ECS, el rol de ejecución/tarea (IAM), y el rol + permiso `ecs:RunTask` de la Lambda que la invoca.

## Comandos

```bash
cd environments/nonprod
terraform init
terraform validate
terraform plan
terraform apply
```

No hay CI, test suite ni linter configurado todavía — la validación se limita a `terraform validate`/`plan` contra credenciales reales de la cuenta destino.

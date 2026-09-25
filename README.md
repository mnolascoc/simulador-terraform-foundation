# poc-account-foundation

Infraestructura como código (Terraform) para la base de cuenta AWS del proyecto **simulador**: motor de extracción que corre como ECS task Fargate, invocado bajo demanda (`RunTask`) desde una Lambda.

## Prerrequisitos

Antes de poder correr `terraform init`/`apply` en este repo (localmente o desde GitHub Actions), hace falta un bootstrap manual **por cuenta AWS** (nonprod, prod). Terraform no puede crear su propio backend remoto, así que estos recursos se crean una sola vez, fuera de este código:

1. **Terraform** `>= 1.9.0` instalado si se va a correr localmente (versión fijada en `backend.tf`; en CI la instala `hashicorp/setup-terraform@v3`).
2. **Bucket S3 para el state**, con versionado y bloqueo de acceso público, uno por cuenta (`simulator-terraform-deploy-mnc` para nonprod — ver `backend.tf`). Debe existir antes del primer `terraform init`, ya que el backend `s3` no se autoprovisiona.
3. **Tabla DynamoDB para locking del state**, con partition key `LockID` (tipo string), una por ambiente (`terraform_locks_nonprod` para nonprod — ver `backend.tf`). Evita que dos `apply` concurrentes corrompan el state.
4. **OIDC provider de GitHub Actions** (`token.actions.githubusercontent.com`) configurado en cada cuenta AWS, y un **rol IAM `terraform-deploy`** por cuenta con trust policy que restrinja qué repo/branch puede asumirlo (ver descripción de `terraform_role_arn` en `variables.tf`). Detalle de ambas políticas más abajo.
5. **Completar `terraform.tfvars`** de cada ambiente con el ARN real de ese rol (`nonprod/terraform.tfvars` trae un placeholder `<NONPROD_ACCOUNT_ID>` a reemplazar) y con los CIDR/AZs que correspondan.
6. **GitHub, a nivel repo:**
   - Secrets `NONPROD_TERRAFORM_ROLE_ARN` y `PROD_TERRAFORM_ROLE_ARN` con el ARN del rol `terraform-deploy` de cada cuenta (los consumen `terraform-plan.yml`/`terraform-apply.yml`).
   - Permisos del workflow (`id-token: write`) habilitados para que `aws-actions/configure-aws-credentials` pueda hacer el intercambio OIDC.
   - **Environments** `nonprod-foundation` y `prod-foundation` creados en Settings → Environments, con reglas de protección — en particular un *required reviewer* en `prod-foundation` para que el `apply` a prod quede bloqueado hasta aprobación manual (ver `terraform-apply.yml`).

Sin estos pasos, el primer `terraform init` falla al no encontrar el bucket/tabla del backend, y los workflows de GitHub Actions fallan al no poder asumir el rol vía OIDC.

### Trust policy del rol `terraform-deploy`

Reemplazar `<AWS_ACCOUNT_ID>` (la cuenta donde vive el rol), `<GITHUB_ORG>/<GITHUB_REPO>` y el nombre del Environment (`nonprod-foundation` o `prod-foundation` según la cuenta). El OIDC provider (`token.actions.githubusercontent.com`) debe estar creado antes en la cuenta.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "[REPO_SUBJECT_CLAIM_PREFIX]:*"
        }
      }
    }
  ]
}
```

- El wildcard final (`:*`) cubre en un solo patrón los tres claims `sub` que este repo necesita: `pull_request` (usa `terraform-plan.yml` en los PRs), `ref:refs/heads/main` (apply por push a `main`) y `environment:<nombre>` (el que GitHub inyecta cuando el job corre bajo un Environment protegido, caso de `terraform-apply.yml`).
- Es más permisivo que listar los tres `sub` exactos — alcanza a cualquier branch/PR/environment de ese repo, no solo `main`/`nonprod-foundation`/`prod-foundation`. Si más adelante se quiere acotar (por ejemplo, que el rol de prod solo se pueda asumir desde el Environment `prod-foundation`), volver a un `StringLike` con la lista explícita de patrones en vez del wildcard genérico.
- **De dónde sale `[REPO_SUBJECT_CLAIM_PREFIX]`**: en el repo de GitHub, ir a **Settings → Actions → General**, bajar hasta la sección de OpenID Connect (o **Settings → Actions → OIDC** según la versión de la UI), y copiar el valor del campo **"Default subject claim prefix"**. Ese es exactamente el prefijo que GitHub va a poner en el claim `sub` del token OIDC para cualquier workflow de este repo.

### Permisos del rol `terraform-deploy`

Política mínima para lo que este repo gestiona hoy (red + VPC endpoints + bucket de artifacts), más el acceso al propio backend de Terraform (bucket de state + tabla de locking). Ajustar `<STATE_BUCKET>`, `<LOCK_TABLE_ARN>` y región según el ambiente.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformStateBackend",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      "Resource": [
        "arn:aws:s3:::<STATE_BUCKET>",
        "arn:aws:s3:::<STATE_BUCKET>/foundation/terraform.tfstate"
      ]
    },
    {
      "Sid": "TerraformStateLock",
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"],
      "Resource": "<LOCK_TABLE_ARN>"
    },
    {
      "Sid": "Networking",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeVpcs", "ec2:CreateVpc", "ec2:DeleteVpc", "ec2:ModifyVpcAttribute",
        "ec2:DescribeSubnets", "ec2:CreateSubnet", "ec2:DeleteSubnet", "ec2:ModifySubnetAttribute",
        "ec2:DescribeInternetGateways", "ec2:CreateInternetGateway", "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway", "ec2:DetachInternetGateway",
        "ec2:DescribeRouteTables", "ec2:CreateRouteTable", "ec2:DeleteRouteTable",
        "ec2:CreateRoute", "ec2:DeleteRoute", "ec2:AssociateRouteTable", "ec2:DisassociateRouteTable",
        "ec2:DescribeVpcEndpoints", "ec2:CreateVpcEndpoint", "ec2:DeleteVpcEndpoints", "ec2:ModifyVpcEndpoint",
        "ec2:DescribeSecurityGroups", "ec2:CreateSecurityGroup", "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupEgress", "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupEgress", "ec2:RevokeSecurityGroupIngress",
        "ec2:DescribeAvailabilityZones", "ec2:CreateTags", "ec2:DeleteTags", "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LambdaArtifactsBucket",
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket", "s3:DeleteBucket", "s3:GetBucketVersioning", "s3:PutBucketVersioning",
        "s3:GetLifecycleConfiguration", "s3:PutLifecycleConfiguration", "s3:GetBucketTagging",
        "s3:PutBucketTagging", "s3:ListBucket", "s3:GetBucketPolicy", "s3:GetEncryptionConfiguration"
      ],
      "Resource": "arn:aws:s3:::simulator-lambda-artifacts-mnc"
    }
  ]
}
```

- El wildcard en `Networking` (`Resource: "*"`) es inevitable con recursos de EC2 (VPC/subnets/etc. no soportan resource-level permissions de forma consistente); si se quiere acotar más, agregar un `Condition` por tag (`aws:ResourceTag/Project = simulador`) una vez que el rol solo se use contra recursos de este proyecto.
- Si más adelante este repo empieza a gestionar el ECS cluster u otros servicios (ver sección "Pendiente de definir" abajo), esta policy va a necesitar los permisos `ecs:*` / `iam:*PassRole` correspondientes — hoy no se incluyen porque no hay recursos de ese tipo en el código.

## Ambientes

| Ambiente | Estado | Cuenta AWS | Uso |
|---|---|---|---|
| `environments/nonprod` | Implementado | Non-Prod (compartida) | dev + uat, mismo bucket de artifacts |
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

### VPC Endpoints — módulo `modules/vpc-endpoints`

| Recurso | Descripción |
|---|---|
| `aws_vpc_endpoint.s3` | Gateway endpoint hacia S3, asociado a las route tables privadas. |
| `aws_vpc_endpoint.dynamodb` | Gateway endpoint hacia DynamoDB, asociado a las route tables privadas. |

Solo Gateway endpoints — sin costo por hora ni por GB, sin trade-off. Los Interface endpoints (ECR, Textract, etc.) se eliminaron del módulo: al correr la ECS task en subnet pública con salida directa por el IGW, no aportarían nada sobre ese camino ya gratuito, y sí tendrían costo fijo por hora + por GB.

Módulo activo en `environments/nonprod/main.tf`.

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

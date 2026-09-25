# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Terraform IaC for the AWS account foundation of the "simulador" project (extraction engine running on ECS Fargate). Provisions per-account networking, VPC endpoints, an ECS cluster, and a shared Lambda artifacts bucket. State is stored remotely in S3 with DynamoDB locking; deploys assume an IAM role via OIDC (intended for GitHub Actions).

Comments and variable descriptions throughout the codebase are written in Spanish — keep new comments/descriptions in Spanish to stay consistent with the existing style.

## Repository layout

- `environments/<env>/` — root modules, one per AWS account. Each wires together the shared modules and holds the backend config, provider/assume-role config, and tfvars for that account.
  - `nonprod/` — implemented; shared by dev and uat (both run in the same non-prod AWS account, e.g. the ECS cluster `simulator-nonprod` is shared between them).
  - `prod/` — not yet implemented (empty directory).
- `modules/` — reusable modules consumed by the environment roots.
  - `vpc/` — VPC, IGW, public/private subnets, one route table per private subnet per AZ (deliberately not shared, to allow per-AZ NAT Gateways later).
  - `vpc-endpoints/` — Gateway endpoints (S3, DynamoDB) only; no cost, always created when the module is used. Interface endpoints were removed from this module — the ECS tasks run in a public subnet with direct IGW egress, so they don't need them.
  - `ecs-cluster/` — ECS cluster with FARGATE + FARGATE_SPOT capacity providers, plus a security group for the cluster's tasks (`aws_security_group.tasks`, egress-only — tasks are invoked via `RunTask` from a Lambda, not over the network, so no ingress rule is needed). Spot is weighted by default (favors cost for interruption-tolerant dev/uat workloads); prod should override `default_capacity_provider_weight_spot = 0` via tfvars if the extraction engine must not run on Spot.
  - `foundation/` — not yet implemented (empty directory).

## Commands

Run from inside an environment directory (e.g. `environments/nonprod`):

```
terraform init
terraform validate
terraform plan
terraform apply
```

There is no CI config, test suite, or linter configured in this repo yet — validation is limited to `terraform validate`/`plan` against real AWS credentials for the target account.

## Architecture notes

- Each environment's `provider.tf` assumes a `terraform-deploy` IAM role (`var.terraform_role_arn`) scoped to that AWS account; `nonprod/terraform.tfvars` and the future `prod/terraform.tfvars` each point to a different account's role. The same `main.tf`/`provider.tf` pattern is meant to work unchanged across environments — only tfvars differ.
- Module wiring order in a root module: `vpc` → `vpc-endpoints` (needs `vpc_id`/subnet/route-table outputs from `vpc`) → `ecs-cluster` (independent, just needs a name). The Lambda artifacts S3 bucket is declared directly in the environment root, not as a module.
- Resource naming convention: `simulador-<environment>-<thing>` (e.g. `simulador-nonprod-vpc`), with `environment` passed down into every module for consistent tagging.
- When adding a new environment root, mirror `environments/nonprod/`'s file split: `backend.tf` (remote state), `provider.tf` (assume-role + default tags), `variables.tf`, `terraform.tfvars`, `main.tf` (module calls + any root-level resources), `output.tf`.
- ECS tasks are invoked on-demand via `RunTask` from a Lambda (not a long-running service behind a load balancer), and currently run in a public subnet with `assign_public_ip = true` for direct internet egress (no NAT Gateway or Interface Endpoints exist in this repo). This is safe only because the tasks' security group has no ingress rules — if a task is ever changed to expose a listening port, revisit this (move to a private subnet + NAT/VPC endpoints, or put a load balancer in front).

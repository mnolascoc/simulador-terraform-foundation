output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "ecs_cluster_name" {
  value = module.ecs_cluster.cluster_name
}

output "ecs_tasks_security_group_id" {
  value = module.ecs_cluster.tasks_security_group_id
}

output "lambda_artifacts_bucket" {
  value = aws_s3_bucket.lambda_artifacts.id
}

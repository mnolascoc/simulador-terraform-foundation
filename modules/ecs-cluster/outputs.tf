output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "tasks_security_group_id" {
  value = aws_security_group.tasks.id
}

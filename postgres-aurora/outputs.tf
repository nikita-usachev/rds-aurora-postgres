output "name" {
  description = "Instance identifier"
  value       = aws_rds_cluster_instance.database.*.id
}

output "address" {
  description = "The Database address"
  value       = aws_rds_cluster_instance.database.*.endpoint
}

output "endpoint" {
  description = "The Database hostname and port combined"
  value       = aws_rds_cluster_instance.database.*.endpoint
}

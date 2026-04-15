# =============================================================================
# DATABASE MODULE — OUTPUTS
#
# These outputs are consumed by:
#   - Other modules (e.g., compute module for API server user data)
#   - Environment-level outputs (so `terraform output` shows connection info)
#   - The Full Stack Developer for local dev / manual testing
#
# IMPORTANT: rds_endpoint and redis_endpoint are NOT secret — they are
# internal DNS names only reachable within the VPC. The PASSWORD is never
# exposed here; it lives only in Secrets Manager.
# =============================================================================

# --- PostgreSQL ---

output "rds_endpoint" {
  description = "RDS PostgreSQL hostname (internal VPC DNS — not reachable from internet)"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS PostgreSQL port (default 5432)"
  value       = aws_db_instance.postgres.port
}

output "rds_db_name" {
  description = "Name of the initial database created inside PostgreSQL"
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "Master username for the PostgreSQL instance"
  value       = aws_db_instance.postgres.username
}

output "rds_instance_id" {
  description = "RDS instance identifier (for use with AWS CLI / console)"
  value       = aws_db_instance.postgres.identifier
}

output "rds_arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance.postgres.arn
}

# --- Redis ---

output "redis_endpoint" {
  description = "ElastiCache Redis hostname (internal VPC DNS — not reachable from internet)"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "ElastiCache Redis port (default 6379)"
  value       = aws_elasticache_cluster.redis.port
}

output "redis_cluster_id" {
  description = "ElastiCache cluster identifier"
  value       = aws_elasticache_cluster.redis.cluster_id
}

# --- Secrets ---

output "db_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing PostgreSQL credentials (host, port, dbname, username, password)"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_credentials_secret_name" {
  description = "Name of the Secrets Manager secret — use this in your app to call GetSecretValue"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "redis_connection_secret_arn" {
  description = "ARN of the Secrets Manager secret containing Redis connection info (host, port, url)"
  value       = aws_secretsmanager_secret.redis_connection.arn
}

output "redis_connection_secret_name" {
  description = "Name of the Redis connection secret — use this in your app to call GetSecretValue"
  value       = aws_secretsmanager_secret.redis_connection.name
}

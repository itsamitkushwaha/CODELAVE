output "api_keys_secret_arn" {
  description = "ARN of the API keys secret (Stripe, SendGrid, JWT) — populate manually after apply"
  value       = aws_secretsmanager_secret.api_keys.arn
}

output "api_keys_secret_name" {
  description = "Name of the API keys secret"
  value       = aws_secretsmanager_secret.api_keys.name
}

# =============================================================================
# SECRETS MANAGER — Per-Environment Placeholder Secrets
#
# This module manages secrets that are NOT tied to a specific infrastructure
# resource (those live in their own modules). Currently:
#
#   - api-keys: Stripe, SendGrid, JWT secret — populated manually after apply:
#
#       aws secretsmanager put-secret-value \
#         --secret-id "codelave/dev/api-keys" \
#         --secret-string '{"stripe_key":"sk_...","sendgrid_key":"SG...","jwt_secret":"..."}'
#
# NOTE: DB credentials (host, port, username, password) are managed by the
# database module, which stores real values from RDS directly into:
#   codelave/<env>/db-credentials
# =============================================================================

locals {
  # Use a customer-managed KMS key if provided, otherwise use no explicit key
  # (AWS Secrets Manager falls back to the AWS-managed default key)
  kms_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
}

# --- API Keys Secret ---
resource "aws_secretsmanager_secret" "api_keys" {
  name        = "codelave/${var.environment}/api-keys"
  description = "Third-party API keys for the Codelave ${var.environment} environment"

  kms_key_id              = local.kms_key_id
  recovery_window_in_days = var.recovery_window_days

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "api-keys"
  }
}

resource "aws_secretsmanager_secret_version" "api_keys_placeholder" {
  secret_id = aws_secretsmanager_secret.api_keys.id
  secret_string = jsonencode({
    stripe_key   = "REPLACE_ME"
    sendgrid_key = "REPLACE_ME"
    jwt_secret   = "REPLACE_ME"
  })

  lifecycle {
    ignore_changes = [secret_string]
  }
}


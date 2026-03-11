output "pii_key_arn" {
  description = "KMS key ARN for PII data (Tier 1)"
  value       = aws_kms_key.pii.arn
}

output "payment_key_arn" {
  description = "KMS key ARN for payment references (Tier 2)"
  value       = aws_kms_key.payment.arn
}

output "fleet_key_arn" {
  description = "KMS key ARN for fleet telemetry (Tier 3)"
  value       = aws_kms_key.fleet.arn
}

output "logs_key_arn" {
  description = "KMS key ARN for audit logs (Tier 4)"
  value       = aws_kms_key.logs.arn
}

output "secrets_key_arn" {
  description = "KMS key ARN for secrets (Tier 5)"
  value       = aws_kms_key.secrets.arn
}

output "biometric_key_arn" {
  description = "KMS key ARN for biometric data — POPIA special category"
  value       = aws_kms_key.biometric.arn
}
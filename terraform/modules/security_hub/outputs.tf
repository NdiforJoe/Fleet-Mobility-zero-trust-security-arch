output "security_hub_arn" {
  description = "Security Hub account ARN"
  value       = aws_securityhub_account.main.id
}

output "cis_standard_arn" {
  description = "CIS Foundations Benchmark subscription ARN"
  value       = aws_securityhub_standards_subscription.cis.id
}

output "nist_standard_arn" {
  description = "NIST 800-53 subscription ARN"
  value       = aws_securityhub_standards_subscription.nist.id
}
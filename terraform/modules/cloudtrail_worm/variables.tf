variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for CloudTrail log encryption — use logs_key_arn from kms_key_set module"
  type        = string
}

variable "retention_days" {
  description = "CloudWatch log retention in days for CloudTrail logs"
  type        = number
  default     = 365
}

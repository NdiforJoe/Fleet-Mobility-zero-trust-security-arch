# ─────────────────────────────────────────────
# GLOBAL VARIABLES
# ─────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region — us-east-1 # for prod use af-south-1 for POPIA data residency"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "avis-zero-trust"
}

# ─────────────────────────────────────────────
# NETWORK VARIABLES
# ─────────────────────────────────────────────

variable "hub_vpc_cidr" {
  description = "CIDR for Hub VPC (security services)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_app_cidr" {
  description = "CIDR for App Spoke VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "spoke_data_cidr" {
  description = "CIDR for Data Spoke VPC (PII — restricted)"
  type        = string
  default     = "10.2.0.0/16"
}

variable "spoke_fleet_cidr" {
  description = "CIDR for Fleet/IoT Spoke VPC"
  type        = string
  default     = "10.3.0.0/16"
}

# ─────────────────────────────────────────────
# SECURITY VARIABLES
# ─────────────────────────────────────────────

variable "alert_email" {
  description = "SOC email for GuardDuty + Security Hub alerts"
  type        = string
  sensitive   = true
}

variable "kms_deletion_window" {
  description = "KMS key deletion window in days (7-30)"
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window >= 7 && var.kms_deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

variable "cloudtrail_retention_days" {
  description = "CloudWatch log retention for CloudTrail (days)"
  type        = number
  default     = 365
}

variable "cognito_mfa_configuration" {
  description = "Cognito MFA setting: OFF, ON, or OPTIONAL"
  type        = string
  default     = "ON"
}
# ─────────────────────────────────────────────
# IAM IDENTITY CENTER VARIABLES
# These values come from the AWS console after
# manually enabling IAM Identity Center.
# See ADR-001 bootstrap note.
# ─────────────────────────────────────────────

variable "sso_instance_arn" {
  description = "IAM Identity Center instance ARN — found in AWS console under IAM Identity Center > Settings"
  type        = string
  default     = "arn:aws:sso:::instance/placeholder"
}

variable "identity_store_id" {
  description = "Identity Store ID — found in AWS console under IAM Identity Center > Settings"
  type        = string
  default     = "d-placeholder"
}

variable "project_name" { type = string }
variable "environment" { type = string }

variable "mfa_configuration" {
  description = "Cognito MFA setting — ON enforces MFA for all users (ADR-005)"
  type        = string
  default     = "ON"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "mfa_configuration must be OFF, ON, or OPTIONAL."
  }
}

variable "kms_key_arn" {
  description = "KMS key ARN for Cognito — use pii_key_arn from kms_key_set module"
  type        = string
}

variable "access_token_validity_minutes" {
  description = "Access token validity in minutes — 15 min for zero-trust blast radius reduction (T-001)"
  type        = number
  default     = 15

  validation {
    condition     = var.access_token_validity_minutes >= 5 && var.access_token_validity_minutes <= 60
    error_message = "Access token validity must be between 5 and 60 minutes."
  }
}

variable "refresh_token_validity_days" {
  description = "Refresh token validity in days"
  type        = number
  default     = 1
}

variable "password_minimum_length" {
  description = "Minimum password length — NIST SP 800-63B recommends 12+"
  type        = number
  default     = 12

  validation {
    condition     = var.password_minimum_length >= 12
    error_message = "Password minimum length must be at least 12 per NIST SP 800-63B."
  }
}

variable "enable_deletion_protection" {
  description = "Enable Cognito user pool deletion protection — always true in prod"
  type        = bool
  default     = false
}

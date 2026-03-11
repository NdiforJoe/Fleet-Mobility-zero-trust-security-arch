variable "project_name" { type = string }
variable "environment"  { type = string }

variable "deletion_window" {
  description = "KMS key deletion window in days (7-30). Validated in root variables.tf."
  type        = number
  default     = 30

  validation {
    condition     = var.deletion_window >= 7 && var.deletion_window <= 30
    error_message = "KMS deletion window must be between 7 and 30 days."
  }
}

variable "enable_key_rotation" {
  description = "Enable automatic annual KMS key rotation. Should always be true in production."
  type        = bool
  default     = true
}
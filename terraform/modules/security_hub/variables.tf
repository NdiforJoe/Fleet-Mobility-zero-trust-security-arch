variable "project_name" { type = string }
variable "environment"  { type = string }

variable "cloudwatch_alarm_threshold" {
  description = "Security Hub CIS compliance score threshold — alarm fires if score drops below this"
  type        = number
  default     = 80

  validation {
    condition     = var.cloudwatch_alarm_threshold >= 0 && var.cloudwatch_alarm_threshold <= 100
    error_message = "Threshold must be between 0 and 100."
  }
}

variable "enable_nist_standard" {
  description = "Enable NIST 800-53 standard in Security Hub — adds additional controls"
  type        = bool
  default     = true
}
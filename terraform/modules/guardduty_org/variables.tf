variable "project_name" { type = string }
variable "environment" { type = string }

variable "alert_email" {
  description = "SOC email address for HIGH and CRITICAL finding alerts"
  type        = string
  sensitive   = true
}

variable "finding_severity_threshold" {
  description = "Minimum GuardDuty severity score to trigger SOC alert (7 = HIGH, 4 = MEDIUM)"
  type        = number
  default     = 7

  validation {
    condition     = var.finding_severity_threshold >= 1 && var.finding_severity_threshold <= 10
    error_message = "Severity threshold must be between 1 and 10."
  }
}

variable "enable_malware_protection" {
  description = "Enable GuardDuty malware protection on EBS volumes"
  type        = bool
  default     = true
}
variable "logs_key_arn" {
  description = "KMS logs key ARN for SNS topic encryption"
  type        = string
}

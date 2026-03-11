variable "project_name" { type = string }
variable "environment"  { type = string }

variable "sso_instance_arn" {
  description = "ARN of the IAM Identity Center instance — must exist before Terraform run"
  type        = string
}

variable "identity_store_id" {
  description = "Identity Store ID from IAM Identity Center"
  type        = string
}

variable "session_duration_staff" {
  description = "Max session duration for branch staff (ISO 8601)"
  type        = string
  default     = "PT4H"
}

variable "session_duration_soc" {
  description = "Max session duration for SOC analysts (ISO 8601)"
  type        = string
  default     = "PT2H"
}

variable "session_duration_admin" {
  description = "Max session duration for admins (ISO 8601)"
  type        = string
  default     = "PT1H"
}
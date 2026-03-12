variable "project_name" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }

variable "aws_region" {
  description = "AWS region — must match root module region"
  type        = string
  default     = "af-south-1"
}

variable "rate_limit_per_ip" {
  description = "Max requests per IP per 5 minutes — T-004 DoS mitigation"
  type        = number
  default     = 1000

  validation {
    condition     = var.rate_limit_per_ip >= 100 && var.rate_limit_per_ip <= 20000
    error_message = "Rate limit must be between 100 and 20000 requests per 5 minutes."
  }
}

variable "geo_block_countries" {
  description = "ISO 3166-1 alpha-2 country codes to geo-block — empty list disables geo-blocking"
  type        = list(string)
  default     = []
}

variable "lambda_authoriser_invoke_arn" {
  description = "Lambda authoriser function invoke ARN — set to placeholder for initial deploy"
  type        = string
  default     = "arn:aws:apigateway:af-south-1:lambda:path/2015-03-31/functions/arn:aws:lambda:af-south-1:123456789012:function:placeholder-authoriser/invocations"
}

variable "waf_log_retention_days" {
  description = "CloudWatch log retention in days for WAF logs"
  type        = number
  default     = 90
}

variable "api_log_retention_days" {
  description = "CloudWatch log retention in days for API Gateway access logs"
  type        = number
  default     = 90
}
variable "logs_key_arn" {
  description = "KMS logs key ARN for CloudWatch log group encryption"
  type        = string
  default     = ""
}

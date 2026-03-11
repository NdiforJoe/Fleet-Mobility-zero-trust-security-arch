variable "project_name" { type = string }
variable "environment"  { type = string }
variable "hub_vpc_cidr"     { type = string }
variable "spoke_app_cidr"   { type = string }
variable "spoke_data_cidr"  { type = string }
variable "spoke_fleet_cidr" { type = string }

variable "aws_region" {
  description = "AWS region for AZ naming"
  type        = string
  default     = "af-south-1"
}
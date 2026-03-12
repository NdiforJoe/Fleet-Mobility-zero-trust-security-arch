output "hub_vpc_id" {
  description = "Hub VPC ID"
  value       = aws_vpc.hub.id
}

output "spoke_app_vpc_id" {
  description = "App Spoke VPC ID"
  value       = aws_vpc.spoke_app.id
}

output "spoke_data_vpc_id" {
  description = "Data Spoke VPC ID — PII restricted"
  value       = aws_vpc.spoke_data.id
}

output "spoke_fleet_vpc_id" {
  description = "Fleet Spoke VPC ID"
  value       = aws_vpc.spoke_fleet.id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID"
  value       = aws_ec2_transit_gateway.main.id
}

output "app_security_group_id" {
  description = "App tier security group ID"
  value       = aws_security_group.app_tier.id
}

output "data_security_group_id" {
  description = "Data tier security group ID — PII restricted"
  value       = aws_security_group.data_tier.id
}

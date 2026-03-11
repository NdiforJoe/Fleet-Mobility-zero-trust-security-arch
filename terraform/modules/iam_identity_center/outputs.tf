output "branch_agent_permission_set_arn" {
  description = "Branch Agent permission set ARN"
  value       = aws_ssoadmin_permission_set.branch_agent.arn
}

output "branch_manager_permission_set_arn" {
  description = "Branch Manager permission set ARN"
  value       = aws_ssoadmin_permission_set.branch_manager.arn
}

output "foreign_desk_agent_permission_set_arn" {
  description = "Foreign Desk Agent permission set ARN"
  value       = aws_ssoadmin_permission_set.foreign_desk_agent.arn
}

output "soc_analyst_permission_set_arn" {
  description = "SOC Analyst permission set ARN"
  value       = aws_ssoadmin_permission_set.soc_analyst.arn
}

output "deny_access_keys_scp_id" {
  description = "SCP ID for DenyCreateAccessKey policy"
  value       = aws_organizations_policy.deny_access_keys.id
}
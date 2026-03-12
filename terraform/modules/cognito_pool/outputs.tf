output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.customers.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN"
  value       = aws_cognito_user_pool.customers.arn
}

output "mobile_client_id" {
  description = "Cognito mobile app client ID"
  value       = aws_cognito_user_pool_client.mobile_app.id
  sensitive   = true
}

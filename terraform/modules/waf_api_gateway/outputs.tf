output "waf_web_acl_arn" {
  description = "WAF Web ACL ARN — attach to CloudFront or API Gateway"
  value       = aws_wafv2_web_acl.api_gateway.arn
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_stage_arn" {
  description = "API Gateway stage ARN — used for WAF association"
  value       = aws_api_gateway_stage.main.arn
}

output "jwt_authoriser_id" {
  description = "Lambda JWT authoriser ID"
  value       = aws_api_gateway_authorizer.jwt.id
}

output "cloudtrail_bucket_arn" {
  description = "S3 bucket ARN for CloudTrail WORM logs"
  value       = aws_s3_bucket.cloudtrail.arn
}

output "cloudtrail_bucket_name" {
  description = "S3 bucket name for CloudTrail WORM logs"
  value       = aws_s3_bucket.cloudtrail.id
}

output "cloudtrail_arn" {
  description = "CloudTrail trail ARN"
  value       = aws_cloudtrail.main.arn
}

output "cloudtrail_log_group_arn" {
  description = "CloudWatch log group ARN for CloudTrail"
  value       = aws_cloudwatch_log_group.cloudtrail.arn
}
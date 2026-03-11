output "guardduty_detector_id" {
  description = "GuardDuty detector ID"
  value       = aws_guardduty_detector.main.id
}

output "security_alerts_topic_arn" {
  description = "SNS topic ARN for security alerts — used by other modules for alarm actions"
  value       = aws_sns_topic.security_alerts.arn
}

output "guardduty_detector_arn" {
  description = "GuardDuty detector ARN"
  value       = aws_guardduty_detector.main.arn
}
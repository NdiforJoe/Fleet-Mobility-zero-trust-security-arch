# ─────────────────────────────────────────────
# GUARDDUTY — Threat Detection
# ADR-006: Primary detection layer
# POPIA s23: Detection-to-alert <15 min
# Enables 72h breach notification SLA
# ─────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_guardduty_detector" "main" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = {
    Name      = "${local.name_prefix}-guardduty"
    ADR       = "ADR-006"
    Regulation = "POPIA-s23-NIST-DE.CM-1"
  }
}

# SNS topic for alerts
resource "aws_sns_topic" "security_alerts" {
  name              = "${local.name_prefix}-security-alerts"
  kms_master_key_id = "alias/aws/sns"

  tags = { Name = "${local.name_prefix}-security-alerts" }
}

resource "aws_sns_topic_subscription" "soc_email" {
  topic_arn = aws_sns_topic.security_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# EventBridge rule — HIGH and CRITICAL findings
# route to SOC within 15 minutes
resource "aws_cloudwatch_event_rule" "guardduty_high" {
  name        = "${local.name_prefix}-guardduty-high-critical"
  description = "Route HIGH and CRITICAL GuardDuty findings to SOC — POPIA s23 SLA chain"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = {
    Name      = "${local.name_prefix}-guardduty-alert-rule"
    STRIDERef = "T-010-T-011"
    Regulation = "POPIA-s23"
  }
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_high.name
  target_id = "SendToSOC"
  arn       = aws_sns_topic.security_alerts.arn
}

# CloudWatch alarm — CloudTrail disabled (T-011)
resource "aws_cloudwatch_metric_alarm" "cloudtrail_disabled" {
  alarm_name          = "${local.name_prefix}-cloudtrail-disabled"
  alarm_description   = "CRITICAL: CloudTrail logging disabled — T-011 cover-up attempt"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "SecurityEventCount"
  namespace           = "CloudTrailMetrics"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_actions       = [aws_sns_topic.security_alerts.arn]

  tags = {
    STRIDERef = "T-011"
    Severity  = "CRITICAL"
  }
}
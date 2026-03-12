# ─────────────────────────────────────────────
# SECURITY HUB — Compliance Aggregation
# ADR-006: Aggregates GuardDuty + CIS Benchmark
# Provides audit-ready compliance score for
# ISO 27001 A.12.4 and NIST CSF DE.CM-1
# depends_on: guardduty_org module
# ─────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_securityhub_account" "main" {
  auto_enable_controls      = true
  control_finding_generator = "SECURITY_CONTROL"
}

# ─────────────────────────────────────────────
# STANDARDS — Three enabled for compliance
# CIS:  Technical security baseline
# FSBP: AWS service-specific best practices
# NIST: Maps directly to NIST CSF functions
# ─────────────────────────────────────────────

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:af-south-1::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.main]
}

resource "aws_securityhub_standards_subscription" "nist" {
  standards_arn = "arn:aws:securityhub:af-south-1::standards/nist-800-53/v/5.0.0"
  depends_on    = [aws_securityhub_account.main]
}

# ─────────────────────────────────────────────
# FINDING AGGREGATOR
# Aggregates findings across all regions
# Single pane of glass for SOC
# ─────────────────────────────────────────────

resource "aws_securityhub_finding_aggregator" "main" {
  linking_mode = "ALL_REGIONS"
  depends_on   = [aws_securityhub_account.main]
}

# ─────────────────────────────────────────────
# CUSTOM INSIGHT — PII Access Anomaly
# Tracks unusual PII decryption events
# Feeds into POPIA s23 breach detection chain
# Application-layer gap GuardDuty cannot cover
# (documented in ADR-006 consequences)
# ─────────────────────────────────────────────

resource "aws_securityhub_insight" "pii_access_anomaly" {
  name = "${local.name_prefix}-pii-access-anomaly"

  filters {
    resource_type {
      comparison = "EQUALS"
      value      = "AwsKmsKey"
    }

    resource_id {
      comparison = "CONTAINS"
      value      = "alias/avis/pii"
    }

    severity_label {
      comparison = "EQUALS"
      value      = "HIGH"
    }
  }

  group_by_attribute = "ResourceId"

  depends_on = [aws_securityhub_account.main]
}

# ─────────────────────────────────────────────
# CLOUDWATCH ALARM — Security Hub critical score
# Fires if CIS compliance score drops below 80%
# Indicator of misconfiguration drift
# ─────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "security_score_drop" {
  alarm_name          = "${local.name_prefix}-security-score-drop"
  alarm_description   = "Security Hub CIS compliance score dropped below threshold — investigate configuration drift"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Security Score"
  namespace           = "AWS/SecurityHub"
  period              = 3600
  statistic           = "Average"
  threshold           = 80

  tags = {
    Name       = "${local.name_prefix}-security-score-alarm"
    ADR        = "ADR-006"
    Regulation = "ISO27001-A.12.4"
  }
}

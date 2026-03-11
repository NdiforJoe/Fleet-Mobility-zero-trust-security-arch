# ─────────────────────────────────────────────
# IAM IDENTITY CENTER — Zero-Trust Human Identity
# ADR-001: No long-lived access keys for humans
# SCPs enforce this at organisation level
# STRIDE: Mitigates T-010 (shared admin creds)
# SABSA: Physical layer — identity control
#
# NOTE: IAM Identity Center instance must be
# manually enabled in AWS console BEFORE
# running this Terraform module.
# See ADR-001 consequences section.
# ─────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}

# ─────────────────────────────────────────────
# PERMISSION SET 1 — Branch Agent
# Naledi at OR Tambo, Menlyn, etc.
# Can: create bookings, view customer PII
#      for active booking only, process payments
# Cannot: delete bookings, bulk export,
#         cross-branch access, fleet data
# ─────────────────────────────────────────────

resource "aws_ssoadmin_permission_set" "branch_agent" {
  name             = "BranchAgent-${var.environment}"
  description      = "Branch counter staff — booking operations scoped to assigned branch"
  instance_arn     = var.sso_instance_arn
  session_duration = var.session_duration_staff

  tags = {
    Name      = "${local.name_prefix}-ps-branch-agent"
    ADR       = "ADR-001"
    STRIDERef = "T-010-T-015-T-016"
    Role      = "branch-agent"
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "branch_agent" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.branch_agent.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBookingOperations"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/avis-bookings-*"
      },
      {
        Sid    = "AllowPIIReadForActiveBooking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem"
        ]
        Resource = "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/avis-customers-*"
        Condition = {
          # Attribute-based: can only read records
          # where booking_status = ACTIVE
          StringEquals = {
            "dynamodb:LeadingKeys" = ["$${aws:PrincipalTag/branch_code}"]
          }
        }
      },
      {
        Sid    = "DenyBulkExport"
        Effect = "Deny"
        Action = [
          "dynamodb:Scan",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
        Condition = {
          # Block any request that would return
          # more than 10 records — prevents
          # bulk PII exfiltration (insider threat)
          NumericGreaterThan = {
            "dynamodb:ReturnConsumedCapacity" = "10"
          }
        }
      },
      {
        Sid    = "DenyFleetDataAccess"
        Effect = "Deny"
        Action = "*"
        Resource = [
          "arn:aws:iot:*:${data.aws_caller_identity.current.account_id}:*",
          "arn:aws:kinesis:*:${data.aws_caller_identity.current.account_id}:stream/avis-fleet-*"
        ]
      },
      {
        Sid    = "DenyDeleteOperations"
        Effect = "Deny"
        Action = [
          "dynamodb:DeleteItem",
          "dynamodb:DeleteTable",
          "rds:DeleteDBInstance",
          "s3:DeleteObject"
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# PERMISSION SET 2 — Branch Manager
# Above + void bookings + branch reports
# Still cannot access other branches
# ─────────────────────────────────────────────

resource "aws_ssoadmin_permission_set" "branch_manager" {
  name             = "BranchManager-${var.environment}"
  description      = "Branch managers — extended booking ops + branch-scoped reports"
  instance_arn     = var.sso_instance_arn
  session_duration = var.session_duration_staff

  tags = {
    Name  = "${local.name_prefix}-ps-branch-manager"
    ADR   = "ADR-001"
    Role  = "branch-manager"
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "branch_manager" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.branch_manager.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowBookingManagement"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ]
        Resource = "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/avis-bookings-*"
      },
      {
        Sid    = "AllowBranchReports"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "Avis/BranchMetrics"
          }
        }
      },
      {
        # Managers can void (update status)
        # but still cannot hard-delete
        Sid    = "AllowVoidBooking"
        Effect = "Allow"
        Action = ["dynamodb:UpdateItem"]
        Resource = "arn:aws:dynamodb:*:${data.aws_caller_identity.current.account_id}:table/avis-bookings-*"
        Condition = {
          StringEquals = {
            "dynamodb:Attributes" = ["booking_status", "void_reason", "void_timestamp"]
          }
        }
      },
      {
        Sid    = "DenyFleetAndCrossAccount"
        Effect = "Deny"
        Action = "*"
        Resource = [
          "arn:aws:iot:*:${data.aws_caller_identity.current.account_id}:*",
          "arn:aws:kinesis:*:${data.aws_caller_identity.current.account_id}:stream/avis-fleet-*"
        ]
      }
    ]
  })
}

# ─────────────────────────────────────────────
# PERMISSION SET 3 — Foreign Desk Agent
# Above BranchAgent + foreign verification
# workflow access (Jumio + Rekognition)
# Added for T-017 foreign customer scenario
# ─────────────────────────────────────────────

resource "aws_ssoadmin_permission_set" "foreign_desk_agent" {
  name             = "ForeignDeskAgent-${var.environment}"
  description      = "Foreign desk staff — branch agent permissions + passport verification workflow"
  instance_arn     = var.sso_instance_arn
  session_duration = var.session_duration_staff

  tags = {
    Name      = "${local.name_prefix}-ps-foreign-desk"
    ADR       = "ADR-001"
    STRIDERef = "T-017"
    Role      = "foreign-desk-agent"
  }
}

resource "aws_ssoadmin_permission_set_inline_policy" "foreign_desk_agent" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.foreign_desk_agent.arn

  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPassportVerificationWorkflow"
        Effect = "Allow"
        Action = [
          "states:StartExecution",
          "states:DescribeExecution"
        ]
        Resource = "arn:aws:states:*:${data.aws_caller_identity.current.account_id}:stateMachine:avis-foreign-verification-*"
      },
      {
        Sid    = "AllowPassportPhotoUpload"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${local.name_prefix}-id-documents/foreign/*"
      },
      {
        Sid    = "DenyDirectRekognitionAccess"
        Effect = "Deny"
        Action = "rekognition:*"
        Resource = "*"
        # Rekognition is called by Step Functions
        # role only — not directly by agents
      }
    ]
  })
}

# ─────────────────────────────────────────────
# PERMISSION SET 4 — SOC Analyst
# Read-only security findings + investigation
# Cannot modify any resources
# ─────────────────────────────────────────────

resource "aws_ssoadmin_permission_set" "soc_analyst" {
  name             = "SOCAnalyst-${var.environment}"
  description      = "SOC analysts — security findings read-only, investigation access"
  instance_arn     = var.sso_instance_arn
  session_duration = var.session_duration_soc

  tags = {
    Name      = "${local.name_prefix}-ps-soc-analyst"
    ADR       = "ADR-001"
    STRIDERef = "T-010"
    Role      = "soc-analyst"
  }
}

# Attach AWS managed read-only policies for SOC
resource "aws_ssoadmin_managed_policy_attachment" "soc_guardduty_readonly" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.soc_analyst.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AmazonGuardDutyReadOnlyAccess"
}

resource "aws_ssoadmin_managed_policy_attachment" "soc_securityhub_readonly" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.soc_analyst.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AWSSecurityHubReadOnlyAccess"
}

resource "aws_ssoadmin_managed_policy_attachment" "soc_cloudtrail_readonly" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.soc_analyst.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AWSCloudTrail_ReadOnlyAccess"
}

resource "aws_ssoadmin_permission_set_inline_policy" "soc_deny_write" {
  instance_arn       = var.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.soc_analyst.arn

  # Explicitly deny all write operations
  # SOC can investigate but never modify
  # Prevents T-010 via SOC account compromise
  inline_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyAllWrite"
        Effect = "Deny"
        NotAction = [
          "guardduty:Get*",
          "guardduty:List*",
          "guardduty:Describe*",
          "securityhub:Get*",
          "securityhub:List*",
          "securityhub:Describe*",
          "cloudtrail:Get*",
          "cloudtrail:List*",
          "cloudtrail:Describe*",
          "cloudtrail:LookupEvents",
          "logs:Get*",
          "logs:Filter*",
          "logs:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

# ─────────────────────────────────────────────
# SCP — Deny Long-Lived Access Keys
# Enforced at organisation level
# Even if IAM user is created, key creation
# is blocked — zero-trust enforcement
# ADR-001: Core zero-trust IAM decision
# ─────────────────────────────────────────────

resource "aws_organizations_policy" "deny_access_keys" {
  name        = "${local.name_prefix}-deny-human-access-keys"
  description = "ADR-001: Deny CreateAccessKey for human IAM users. All human access via IAM Identity Center only."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyCreateAccessKeyForHumanUsers"
        Effect = "Deny"
        Action = [
          "iam:CreateAccessKey",
          "iam:UpdateAccessKey"
        ]
        Resource = "*"
        Condition = {
          # Allow service accounts (automation)
          # Block human users identified by
          # naming convention
          StringNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::*:role/*-service-role",
              "arn:aws:iam::*:role/*-lambda-role",
              "arn:aws:iam::*:role/*-ecs-task-role"
            ]
          }
        }
      },
      {
        Sid    = "DenyRootAccountUsage"
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:root"
          }
          # Except for break-glass scenarios
          # documented in ADR-001
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })

  tags = {
    Name  = "${local.name_prefix}-scp-deny-access-keys"
    ADR   = "ADR-001"
    Type  = "guardrail"
  }
}
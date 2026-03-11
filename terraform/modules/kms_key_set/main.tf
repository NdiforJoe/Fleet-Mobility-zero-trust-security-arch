# ─────────────────────────────────────────────
# KMS CUSTOMER MANAGED KEYS — 6 KEYS
# ADR-004: Separate CMK per data classification
# Blast radius reduction — one key compromise
# does not expose all data tiers
# STRIDE: Mitigates T-005, T-011, T-013
# ─────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ─────────────────────────────────────────────
# KMS KEY 1 — PII (Tier 1: SA ID, passport,
#             address, driver's licence)
# POPIA: Special protection required
# ─────────────────────────────────────────────

resource "aws_kms_key" "pii" {
  description             = "Avis PII encryption — SA IDs, passports, addresses. POPIA Tier 1."
  deletion_window_in_days = var.deletion_window
  enable_key_rotation     = true
  multi_region            = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowAuroraEncryption"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyNonPIIServices"
        Effect = "Deny"
        Principal = { AWS = "*" }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalServiceName" = [
              "rds.amazonaws.com",
              "lambda.amazonaws.com",
              "s3.amazonaws.com"
            ]
          }
          StringNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-booking-service-role",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name           = "${local.name_prefix}-kms-pii"
    Classification = "PII-TIER-1"
    POPIAScope     = "true"
    ADR            = "ADR-004"
    Regulation     = "POPIA-s19-GDPR-Art32"
  }
}

resource "aws_kms_alias" "pii" {
  name          = "alias/avis/pii"
  target_key_id = aws_kms_key.pii.key_id
}

# ─────────────────────────────────────────────
# KMS KEY 2 — PAYMENT (Tier 2: PAN refs,
#             transaction IDs)
# PCI-DSS Requirement 3.5 — key separation
# ─────────────────────────────────────────────

resource "aws_kms_key" "payment" {
  description             = "Avis payment references — masked PAN, transaction IDs. PCI-DSS Tier 2."
  deletion_window_in_days = var.deletion_window
  enable_key_rotation     = true

  tags = {
    Name           = "${local.name_prefix}-kms-payment"
    Classification = "PAYMENT-TIER-2"
    PCIDSSScope    = "true"
    ADR            = "ADR-004"
    Regulation     = "PCI-DSS-Req3.5"
  }
}

resource "aws_kms_alias" "payment" {
  name          = "alias/avis/payment"
  target_key_id = aws_kms_key.payment.key_id
}

# ─────────────────────────────────────────────
# KMS KEY 3 — FLEET (Tier 3: GPS, VIN, speed)
# ─────────────────────────────────────────────

resource "aws_kms_key" "fleet" {
  description             = "Avis fleet telemetry — GPS coordinates, VIN, speed data."
  deletion_window_in_days = var.deletion_window
  enable_key_rotation     = true

  tags = {
    Name           = "${local.name_prefix}-kms-fleet"
    Classification = "FLEET-TIER-3"
    ADR            = "ADR-004"
  }
}

resource "aws_kms_alias" "fleet" {
  name          = "alias/avis/fleet"
  target_key_id = aws_kms_key.fleet.key_id
}

# ─────────────────────────────────────────────
# KMS KEY 4 — LOGS (Tier 4: CloudTrail, app logs)
# STRIDE T-011: Separate key in separate account
# prevents production compromise destroying
# audit evidence
# ─────────────────────────────────────────────

resource "aws_kms_key" "logs" {
  description             = "Avis audit logs — CloudTrail, VPC Flow Logs. WORM evidence."
  deletion_window_in_days = var.deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudTrail"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name           = "${local.name_prefix}-kms-logs"
    Classification = "AUDIT-LOGS-TIER-4"
    STRIDERef      = "T-011"
    ADR            = "ADR-004"
    Regulation     = "ISO27001-A.12.4"
  }
}

resource "aws_kms_alias" "logs" {
  name          = "alias/avis/logs"
  target_key_id = aws_kms_key.logs.key_id
}

# ─────────────────────────────────────────────
# KMS KEY 5 — SECRETS (Tier 5: DB passwords,
#             API keys, certificates)
# ─────────────────────────────────────────────

resource "aws_kms_key" "secrets" {
  description             = "Avis secrets — DB credentials, API keys. Secrets Manager."
  deletion_window_in_days = var.deletion_window
  enable_key_rotation     = true

  tags = {
    Name           = "${local.name_prefix}-kms-secrets"
    Classification = "SECRETS-TIER-5"
    ADR            = "ADR-004"
  }
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/avis/secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# ─────────────────────────────────────────────
# KMS KEY 6 — BIOMETRIC (passport photos,
#             Rekognition face comparison data)
# POPIA: Special category — heightened protection
# Added during T-017 foreign customer scenario
# ─────────────────────────────────────────────

resource "aws_kms_key" "biometric" {
  description             = "Avis biometric data — passport scans, counter photos, Rekognition results. POPIA special category."
  deletion_window_in_days = var.deletion_window
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowRekognitionOnly"
        Effect = "Allow"
        Principal = {
          Service = "rekognition.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyAllExceptRekognitionAndVerificationRole"
        Effect = "Deny"
        Principal = { AWS = "*" }
        Action    = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalServiceName" = "rekognition.amazonaws.com"
          }
          StringNotLike = {
            "aws:PrincipalArn" = [
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.name_prefix}-foreign-verification-role",
              "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name           = "${local.name_prefix}-kms-biometric"
    Classification = "BIOMETRIC-SPECIAL-CATEGORY"
    POPIAScope     = "true"
    STRIDERef      = "T-017"
    ADR            = "ADR-004"
    Regulation     = "POPIA-SpecialCategory"
  }
}

resource "aws_kms_alias" "biometric" {
  name          = "alias/avis/biometric"
  target_key_id = aws_kms_key.biometric.key_id
}
# ─────────────────────────────────────────────
# COGNITO USER POOL — Customer Authentication
# ADR-005: POPIA data residency af-south-1
# AFSM: ML anomaly detection for T-001
# STRIDE: Mitigates T-001, T-002, T-012, T-013
# ─────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_cognito_user_pool" "customers" {
  name = "${local.name_prefix}-customer-pool"

  # Password policy — NIST SP 800-63B compliant
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 1
  }

  # MFA — ON for all users (ADR-005)
  mfa_configuration = var.mfa_configuration

  software_token_mfa_configuration {
    enabled = true
  }

  # Advanced Security Mode — ML anomaly detection
  # Directly mitigates T-001 (JWT replay from
  # new device / impossible travel)
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  # Email verification required
  auto_verified_attributes = ["email"]

  # Schema — custom attributes for zero-trust
  schema {
    name                = "device_fingerprint"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "branch_code"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 20
    }
  }

  # Deletion protection
  deletion_protection = var.environment == "prod" ? "ACTIVE" : "INACTIVE"

  tags = {
    Name       = "${local.name_prefix}-cognito-customer-pool"
    ADR        = "ADR-005"
    STRIDERef  = "T-001-T-002-T-012-T-013"
    POPIAScope = "true"
    Regulation = "POPIA-s19-s26"
  }
}

# User pool client — PKCE for mobile app
# No client secret (T-012: nothing to extract
# from reverse-engineered mobile binary)
resource "aws_cognito_user_pool_client" "mobile_app" {
  name         = "${local.name_prefix}-mobile-client"
  user_pool_id = aws_cognito_user_pool.customers.id

  # No client secret — PKCE flow only
  generate_secret = false

  # Token validity
  access_token_validity  = 15
  id_token_validity      = 15
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # PKCE required for mobile
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO"]

  # Prevent user enumeration (T-001 variant)
  prevent_user_existence_errors = "ENABLED"

  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]
}

# User groups — role separation (T-002)
resource "aws_cognito_user_group" "customers" {
  name         = "customers"
  user_pool_id = aws_cognito_user_pool.customers.id
  description  = "Standard customers — booking access only"
  precedence   = 10
}

resource "aws_cognito_user_group" "premium_customers" {
  name         = "premium-customers"
  user_pool_id = aws_cognito_user_pool.customers.id
  description  = "Premium tier — additional vehicle classes"
  precedence   = 5
}

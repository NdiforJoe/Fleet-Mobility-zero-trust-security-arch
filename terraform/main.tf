# ─────────────────────────────────────────────
# ROOT MODULE
# Wires all 8 security modules together.
# Each module maps to an ADR and SABSA layer.
# All resources deploy to af-south-1
# for POPIA data residency (ADR-005).
# ─────────────────────────────────────────────

# MODULE 2 — IAM Identity Center (ADR-001)
# STRIDE: T-010, T-015 — no long-lived keys
module "iam_identity_center" {
  source = "./modules/iam_identity_center"

  project_name      = var.project_name
  environment       = var.environment
  sso_instance_arn  = var.sso_instance_arn
  identity_store_id = var.identity_store_id
}

# MODULE 3 — KMS Key Set (ADR-004)
# STRIDE: T-005, T-011, T-013
module "kms_key_set" {
  source = "./modules/kms_key_set"

  project_name    = var.project_name
  environment     = var.environment
  deletion_window = var.kms_deletion_window
}

# MODULE 4 — GuardDuty (ADR-006)
# POPIA s23: detection-to-alert < 15 min
module "guardduty_org" {
  source = "./modules/guardduty_org"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email
  logs_key_arn = module.kms_key_set.logs_key_arn

  depends_on = [module.kms_key_set]
}

# MODULE 5 — Security Hub (ADR-006)
# CIS + FSBP + NIST-800-53 standards
module "security_hub" {
  source = "./modules/security_hub"

  project_name               = var.project_name
  environment                = var.environment
  cloudwatch_alarm_threshold = 80
  enable_nist_standard       = true

  depends_on = [module.guardduty_org]
}

# MODULE 6 — CloudTrail WORM (ADR-004)
# STRIDE: T-011 — immutable audit logs
module "cloudtrail_worm" {
  source = "./modules/cloudtrail_worm"

  project_name   = var.project_name
  environment    = var.environment
  kms_key_arn    = module.kms_key_set.logs_key_arn
  retention_days = var.cloudtrail_retention_days

  depends_on = [module.kms_key_set]
}

# MODULE 7 — WAF + API Gateway (ADR-003)
# STRIDE: T-003, T-004, T-005, T-012
module "waf_api_gateway" {
  source = "./modules/waf_api_gateway"

  project_name           = var.project_name
  environment            = var.environment
  aws_region             = var.aws_region
  vpc_id                 = module.vpc_hub_spoke.hub_vpc_id
  logs_key_arn           = module.kms_key_set.logs_key_arn
  rate_limit_per_ip      = 1000
  geo_block_countries    = []
  waf_log_retention_days = 90
  api_log_retention_days = 90

  depends_on = [module.vpc_hub_spoke, module.kms_key_set]
}

# MODULE 8 — Cognito User Pool (ADR-005)
# STRIDE: T-001, T-002, T-012, T-013
module "cognito_pool" {
  source = "./modules/cognito_pool"

  project_name                  = var.project_name
  environment                   = var.environment
  mfa_configuration             = var.cognito_mfa_configuration
  kms_key_arn                   = module.kms_key_set.pii_key_arn
  access_token_validity_minutes = 15
  refresh_token_validity_days   = 1
  password_minimum_length       = 12
  enable_deletion_protection    = var.environment == "prod" ? true : false

  depends_on = [module.kms_key_set]
}
# MODULE 1 — VPC Hub-Spoke (ADR-003)
# STRIDE: T-005, T-006 lateral movement

module "vpc_hub_spoke" {
  source = "./modules/vpc_hub_spoke"

  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  hub_vpc_cidr     = var.hub_vpc_cidr
  spoke_app_cidr   = var.spoke_app_cidr
  spoke_data_cidr  = var.spoke_data_cidr
  spoke_fleet_cidr = var.spoke_fleet_cidr
  logs_key_arn     = module.kms_key_set.logs_key_arn

  depends_on = [module.kms_key_set]
}

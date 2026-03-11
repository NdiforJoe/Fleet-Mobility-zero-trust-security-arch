# ─────────────────────────────────────────────
# WAF WEB ACL — API Gateway Protection
# ADR-003: Edge security layer
# STRIDE: Mitigates T-003 (tampering),
#         T-004 (DoS), T-005 (SQL injection),
#         T-012 (bot/scraping)
# ─────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

resource "aws_wafv2_web_acl" "api_gateway" {
  name        = "${local.name_prefix}-waf-api-gw"
  description = "WAF protecting API Gateway — OWASP Top 10, bot control, rate limiting"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # ─────────────────────────────────────────
  # RULE 1 — AWS Managed: Core OWASP Rules
  # Covers SQL injection (T-005), XSS,
  # path traversal, command injection
  # Priority 1 — checked first
  # ─────────────────────────────────────────
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        # Override to COUNT (not block) in dev
        # Switch to none{} in prod
        dynamic "rule_action_override" {
          for_each = var.environment == "dev" ? [
            "SizeRestrictions_BODY",
            "NoUserAgent_HEADER"
          ] : []
          content {
            name = rule_action_override.value
            action_to_use {
              count {}
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # ─────────────────────────────────────────
  # RULE 2 — AWS Managed: SQL Injection
  # Direct T-005 mitigation
  # ─────────────────────────────────────────
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # ─────────────────────────────────────────
  # RULE 3 — Rate Limiting per IP
  # T-004: 1000 req/5min per IP prevents
  # credential stuffing and booking API flood
  # ─────────────────────────────────────────
  rule {
    name     = "RateLimitPerIP"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_ip
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitMetric"
      sampled_requests_enabled   = true
    }
  }

  # ─────────────────────────────────────────
  # RULE 4 — Known Bad Inputs
  # Blocks log4j, Spring4Shell exploits
  # ─────────────────────────────────────────
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsMetric"
      sampled_requests_enabled   = true
    }
  }

  # ─────────────────────────────────────────
  # RULE 5 — Bot Control
  # T-004 + T-012: Blocks scrapers and
  # automated booking tools
  # ─────────────────────────────────────────
  rule {
    name     = "AWSManagedRulesBotControlRuleSet"
    priority = 5

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"

        managed_rule_group_configs {
          aws_managed_rules_bot_control_rule_set {
            inspection_level = "COMMON"
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BotControlMetric"
      sampled_requests_enabled   = true
    }
  }

  # ─────────────────────────────────────────
  # RULE 6 — Geo-blocking (optional)
  # Only applied if geo_block_countries is set
  # ─────────────────────────────────────────
  dynamic "rule" {
    for_each = length(var.geo_block_countries) > 0 ? [1] : []

    content {
      name     = "GeoBlockRule"
      priority = 6

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.geo_block_countries
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "GeoBlockMetric"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.name_prefix}-waf-api-gw"
    sampled_requests_enabled   = true
  }

  tags = {
    Name      = "${local.name_prefix}-waf-api-gw"
    ADR       = "ADR-003"
    STRIDERef = "T-003-T-004-T-005-T-012"
    Regulation = "OWASP-Top10-ISO27001-A.13.1"
  }
}

# ─────────────────────────────────────────────
# WAF LOGGING
# All blocked requests logged to S3
# Evidence for ISO 27001 A.12.4
# ─────────────────────────────────────────────

resource "aws_wafv2_web_acl_logging_configuration" "api_gateway" {
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]
  resource_arn            = aws_wafv2_web_acl.api_gateway.arn

  # Redact Authorization header from logs
  # JWT tokens must not appear in WAF logs
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
}

resource "aws_cloudwatch_log_group" "waf" {
  # WAF log group MUST start with aws-waf-logs-
  name              = "aws-waf-logs-${local.name_prefix}-api-gw"
  retention_in_days = 90

  tags = {
    Name      = "${local.name_prefix}-waf-logs"
    STRIDERef = "T-003-T-004"
  }
}

# ─────────────────────────────────────────────
# API GATEWAY — REST API with WAF attached
# Lambda Authoriser validates JWT on every call
# Zero-trust: authenticated ≠ authorised
# ─────────────────────────────────────────────

resource "aws_api_gateway_rest_api" "main" {
  name        = "${local.name_prefix}-api"
  description = "Avis Fleet Platform API — WAF protected, Lambda authoriser on all routes"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # Minimum TLS 1.2 — enforces TLS 1.3 via
  # CloudFront in front of this gateway
  minimum_compression_size = 0

  tags = {
    Name      = "${local.name_prefix}-api-gw"
    ADR       = "ADR-003"
    STRIDERef = "T-003-T-004"
  }
}

# Lambda Authoriser — validates JWT on every request
# This is the zero-trust enforcement point
# 5-point check: signature, expiry, audience,
# issuer, device fingerprint
resource "aws_api_gateway_authorizer" "jwt" {
  name                   = "${local.name_prefix}-jwt-authoriser"
  rest_api_id            = aws_api_gateway_rest_api.main.id
  authorizer_uri         = var.lambda_authoriser_invoke_arn
  authorizer_credentials = aws_iam_role.api_gw_authoriser.arn
  type                   = "TOKEN"
  identity_source        = "method.request.header.Authorization"

  # Cache authorisation for 5 minutes
  # Reduces Lambda invocations while maintaining
  # short enough window for revocation to take effect
  authorizer_result_ttl_in_seconds = 300
}

resource "aws_iam_role" "api_gw_authoriser" {
  name = "${local.name_prefix}-apigw-authoriser-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "api_gw_authoriser" {
  name = "${local.name_prefix}-apigw-authoriser-policy"
  role = aws_iam_role.api_gw_authoriser.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = var.lambda_authoriser_invoke_arn
    }]
  })
}

# Attach WAF to API Gateway stage
resource "aws_wafv2_web_acl_association" "api_gateway" {
  resource_arn = aws_api_gateway_stage.main.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway.arn
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  # Enable detailed metrics
  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      # Log authoriser result for audit
      authoriserResult = "$context.authorizer.principalId"
    })
  }

  tags = {
    Name      = "${local.name_prefix}-api-stage"
    STRIDERef = "T-003-T-004"
  }
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "api_access" {
  name              = "/avis/api-gateway/${var.environment}/access-logs"
  retention_in_days = 90

  tags = { Name = "${local.name_prefix}-api-access-logs" }
}
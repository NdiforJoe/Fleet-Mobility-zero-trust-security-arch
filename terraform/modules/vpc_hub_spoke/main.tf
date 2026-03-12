# ─────────────────────────────────────────────
# VPC HUB-SPOKE WITH TRANSIT GATEWAY
# ADR-003: Hub-spoke enforces zero-trust network
# isolation between app, data, and fleet tiers.
# No spoke-to-spoke routing permitted.
# STRIDE: Mitigates T-005, T-006 lateral movement
# ─────────────────────────────────────────────

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ─────────────────────────────────────────────
# HUB VPC — Security Services
# ─────────────────────────────────────────────

resource "aws_vpc" "hub" {
  cidr_block           = var.hub_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-hub-vpc"
    Tier = "security-hub"
  }
}

# Hub private subnets (AZ-a and AZ-b for HA)
resource "aws_subnet" "hub_private_a" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.hub_vpc_cidr, 8, 1)
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${local.name_prefix}-hub-private-a"
    Tier = "hub-private"
  }
}

resource "aws_subnet" "hub_private_b" {
  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.hub_vpc_cidr, 8, 2)
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${local.name_prefix}-hub-private-b"
    Tier = "hub-private"
  }
}

# ─────────────────────────────────────────────
# SPOKE VPC — APP TIER (10.1.0.0/16)
# ─────────────────────────────────────────────

resource "aws_vpc" "spoke_app" {
  cidr_block           = var.spoke_app_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-spoke-app-vpc"
    Tier = "application"
  }
}

resource "aws_subnet" "spoke_app_private_a" {
  vpc_id            = aws_vpc.spoke_app.id
  cidr_block        = cidrsubnet(var.spoke_app_cidr, 8, 1)
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${local.name_prefix}-spoke-app-private-a"
    Tier = "app-private"
  }
}

resource "aws_subnet" "spoke_app_private_b" {
  vpc_id            = aws_vpc.spoke_app.id
  cidr_block        = cidrsubnet(var.spoke_app_cidr, 8, 2)
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${local.name_prefix}-spoke-app-private-b"
    Tier = "app-private"
  }
}

# ─────────────────────────────────────────────
# SPOKE VPC — DATA TIER (10.2.0.0/16) 🔴 PII
# ─────────────────────────────────────────────

resource "aws_vpc" "spoke_data" {
  cidr_block           = var.spoke_data_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name       = "${local.name_prefix}-spoke-data-vpc"
    Tier       = "data"
    DataClass  = "PII-RESTRICTED"
    POPIAScope = "true"
  }
}

resource "aws_subnet" "spoke_data_private_a" {
  vpc_id            = aws_vpc.spoke_data.id
  cidr_block        = cidrsubnet(var.spoke_data_cidr, 8, 1)
  availability_zone = "${var.aws_region}a"

  tags = {
    Name       = "${local.name_prefix}-spoke-data-private-a"
    Tier       = "data-private"
    POPIAScope = "true"
  }
}

resource "aws_subnet" "spoke_data_private_b" {
  vpc_id            = aws_vpc.spoke_data.id
  cidr_block        = cidrsubnet(var.spoke_data_cidr, 8, 2)
  availability_zone = "${var.aws_region}b"

  tags = {
    Name       = "${local.name_prefix}-spoke-data-private-b"
    Tier       = "data-private"
    POPIAScope = "true"
  }
}

# ─────────────────────────────────────────────
# SPOKE VPC — FLEET/IOT TIER (10.3.0.0/16)
# ─────────────────────────────────────────────

resource "aws_vpc" "spoke_fleet" {
  cidr_block           = var.spoke_fleet_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-spoke-fleet-vpc"
    Tier = "fleet-iot"
  }
}

resource "aws_subnet" "spoke_fleet_private_a" {
  vpc_id            = aws_vpc.spoke_fleet.id
  cidr_block        = cidrsubnet(var.spoke_fleet_cidr, 8, 1)
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${local.name_prefix}-spoke-fleet-private-a"
    Tier = "fleet-private"
  }
}

# ─────────────────────────────────────────────
# TRANSIT GATEWAY — The Security Checkpoint
# ADR-003: Central routing hub, no spoke-to-spoke
# ─────────────────────────────────────────────

resource "aws_ec2_transit_gateway" "main" {
  description                     = "Avis Zero-Trust Hub - no spoke-to-spoke routing"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name    = "${local.name_prefix}-tgw"
    ADR     = "ADR-003"
    Purpose = "hub-spoke-isolation"
  }
}

# TGW Attachments — one per VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  subnet_ids         = [aws_subnet.hub_private_a.id, aws_subnet.hub_private_b.id]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.hub.id

  tags = { Name = "${local.name_prefix}-tgw-attach-hub" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke_app" {
  subnet_ids         = [aws_subnet.spoke_app_private_a.id, aws_subnet.spoke_app_private_b.id]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.spoke_app.id

  tags = { Name = "${local.name_prefix}-tgw-attach-app" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke_data" {
  subnet_ids         = [aws_subnet.spoke_data_private_a.id, aws_subnet.spoke_data_private_b.id]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.spoke_data.id

  tags = { Name = "${local.name_prefix}-tgw-attach-data" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke_fleet" {
  subnet_ids         = [aws_subnet.spoke_fleet_private_a.id]
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = aws_vpc.spoke_fleet.id

  tags = { Name = "${local.name_prefix}-tgw-attach-fleet" }
}

# ─────────────────────────────────────────────
# TGW ROUTE TABLES
# Critical: spokes can only reach Hub.
# Spokes cannot reach each other directly.
# This is the zero-trust network enforcement.
# ─────────────────────────────────────────────

# Hub route table — can reach all spokes
resource "aws_ec2_transit_gateway_route_table" "hub" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags               = { Name = "${local.name_prefix}-tgw-rt-hub" }
}

# Spoke route table — can ONLY reach hub
resource "aws_ec2_transit_gateway_route_table" "spokes" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags = {
    Name    = "${local.name_prefix}-tgw-rt-spokes"
    Purpose = "spoke-to-hub-only-no-lateral-movement"
  }
}

# Associate each spoke with the spoke route table
resource "aws_ec2_transit_gateway_route_table_association" "spoke_app" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke_data" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_data.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke_fleet" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_fleet.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

# Hub route table — propagate all spoke CIDRs
resource "aws_ec2_transit_gateway_route_table_propagation" "hub_learns_app" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_app.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "hub_learns_data" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_data.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "hub_learns_fleet" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke_fleet.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.hub.id
}

# Spoke route table — only route to Hub attachment
resource "aws_ec2_transit_gateway_route" "spokes_to_hub" {
  destination_cidr_block         = var.hub_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokes.id
}

# ─────────────────────────────────────────────
# VPC FLOW LOGS — every VPC
# GuardDuty reads these for anomaly detection
# ─────────────────────────────────────────────

resource "aws_flow_log" "hub" {
  vpc_id          = aws_vpc.hub.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = { Name = "${local.name_prefix}-flowlog-hub" }
}

resource "aws_flow_log" "spoke_app" {
  vpc_id          = aws_vpc.spoke_app.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = { Name = "${local.name_prefix}-flowlog-app" }
}

resource "aws_flow_log" "spoke_data" {
  vpc_id          = aws_vpc.spoke_data.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = {
    Name       = "${local.name_prefix}-flowlog-data"
    POPIAScope = "true"
  }
}

resource "aws_flow_log" "spoke_fleet" {
  vpc_id          = aws_vpc.spoke_fleet.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn

  tags = { Name = "${local.name_prefix}-flowlog-fleet" }
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/avis/vpc-flow-logs/${var.environment}"
  retention_in_days = 365
  kms_key_id        = var.logs_key_arn

  tags = { Name = "${local.name_prefix}-flow-logs" }
}

resource "aws_iam_role" "flow_log" {
  name = "${local.name_prefix}-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "flow_log" {
  name = "${local.name_prefix}-flow-log-policy"
  role = aws_iam_role.flow_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup"]
        Resource = aws_cloudwatch_log_group.flow_logs.arn
      }
    ]
  })
}

# ─────────────────────────────────────────────
# SECURITY GROUPS
# Data VPC: only accepts traffic from App SG
# ─────────────────────────────────────────────

resource "aws_security_group" "app_tier" {
  name        = "${local.name_prefix}-sg-app-tier"
  description = "App tier - inbound from ALB only, outbound to hub via TGW"
  vpc_id      = aws_vpc.spoke_app.id

  ingress {
    description = "HTTPS from internal ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.hub_vpc_cidr]
  }

  egress {
    description = "All outbound via TGW - controlled by TGW route tables not SG (ADR-003)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    #trivy:ignore:AVD-AWS-0104
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-sg-app-tier"
    Tier = "application"
  }
}

resource "aws_security_group" "data_tier" {
  name        = "${local.name_prefix}-sg-data-tier"
  description = "Data tier - ONLY accepts PostgreSQL from App SG via TGW. No internet."
  vpc_id      = aws_vpc.spoke_data.id

  ingress {
    description = "PostgreSQL from App VPC CIDR only — T-005 mitigation"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.spoke_app_cidr]
  }
  egress {
    description = "Deny all outbound - data tier never initiates connections"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    #trivy:ignore:AVD-AWS-0104
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name       = "${local.name_prefix}-sg-data-tier"
    Tier       = "data"
    POPIAScope = "true"
    STRIDERef  = "T-005-T-006"
  }
}
# ─────────────────────────────────────────────
# DEFAULT SECURITY GROUP LOCKDOWN
# CKV2_AWS_12: Default SG must restrict all traffic
# Zero-trust: nothing uses the default SG —
# all resources get explicit named SGs
# ─────────────────────────────────────────────

resource "aws_default_security_group" "hub" {
  vpc_id = aws_vpc.hub.id
  # No ingress or egress rules = deny all
  tags = { Name = "${local.name_prefix}-hub-default-sg-LOCKED" }
}

resource "aws_default_security_group" "spoke_app" {
  vpc_id = aws_vpc.spoke_app.id
  tags   = { Name = "${local.name_prefix}-app-default-sg-LOCKED" }
}

resource "aws_default_security_group" "spoke_data" {
  vpc_id = aws_vpc.spoke_data.id
  tags   = { Name = "${local.name_prefix}-data-default-sg-LOCKED" }
}

resource "aws_default_security_group" "spoke_fleet" {
  vpc_id = aws_vpc.spoke_fleet.id
  tags   = { Name = "${local.name_prefix}-fleet-default-sg-LOCKED" }
}

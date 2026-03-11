terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "avis-zero-trust"
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "security-architecture"
      CostCentre  = "security"
    }
  }
}
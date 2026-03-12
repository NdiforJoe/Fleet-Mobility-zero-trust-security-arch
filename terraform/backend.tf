# ─────────────────────────────────────────────
# REMOTE STATE — S3 + DYNAMODB LOCK
# ─────────────────────────────────────────────
# NOTE: Create the S3 bucket and DynamoDB table
# manually BEFORE running terraform init.
# This is the chicken-and-egg bootstrap problem
# documented in ADR-001.
#
# Bootstrap commands:
#   aws s3 mb s3://avis-zero-trust-tfstate-<account-id> \
#     --region us-east-1
#   aws s3api put-bucket-versioning \
#     --bucket avis-zero-trust-tfstate-<account-id> \
#     --versioning-configuration Status=Enabled
#   aws dynamodb create-table \
#     --table-name avis-zero-trust-tflock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST \
#     --region us-east-1
# ─────────────────────────────────────────────

terraform {
  backend "s3" {
    bucket       = "avis-zero-trust-tfstate-074928164064"
    key          = "core/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

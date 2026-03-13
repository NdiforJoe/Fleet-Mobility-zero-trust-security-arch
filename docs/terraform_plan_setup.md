# Terraform Plan Job — AWS Authentication Setup

## Why the terraform-plan job is disabled by default

The `terraform-plan` job requires AWS credentials to run `terraform plan`.
This environment uses AWS IAM Identity Center (SSO) — no long-term
`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` credentials exist by design.
This is a zero-trust IAM control (ADR-001).

## Enabling via OIDC in production

1. Create an IAM role trusting GitHub Actions OIDC provider
2. Add role ARN as GitHub Secret: `AWS_OIDC_ROLE_ARN`
3. Replace credentials step with:

```yaml
- name: Configure AWS credentials via OIDC
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_OIDC_ROLE_ARN }}
    aws-region: af-south-1
```

1. Change `if: false` back to:
   `if: github.ref == 'refs/heads/main' && github.event_name == 'push'`

**Regulation:** ISO 27001 A.9.4.2, NIST IA-5

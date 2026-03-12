# ADR-004: Separate KMS CMK per Data Classification Tier

| Field | Value |
|-------|-------|
| Status | Accepted |
| Date | 2025-Q1 |
| Deciders | Security Architect, Data Architect, Compliance Manager |
| SABSA Layer | Component (cryptographic control implementation) |

---

## Context

AWS KMS supports both AWS-managed keys (free, automatic) and
Customer Managed Keys (CMKs, $1/key/month, configurable key policy).
The decision is whether to use one CMK for all encrypted data, or
separate CMKs per data classification tier (PII, Payment, Fleet,
Audit Logs, Secrets). This decision affects compliance posture,
blast radius of key compromise, and auditability.

## Decision

Provision five separate KMS CMKs, each dedicated to a single data
classification tier: `alias/avis/pii`, `alias/avis/payment`,
`alias/avis/fleet`, `alias/avis/logs`, `alias/avis/secrets`.
Each CMK has an independent key policy granting only the AWS services
that process that specific data tier.

## Rationale

- **ISO 27001 A.10.1.1** requires documented key management procedures
  including separation of key custodians for different purposes
- **PCI-DSS Requirement 3.5** requires separate key custodians for
  payment-related keys — satisfied by payment CMK with restricted policy
- **Blast radius reduction:** Compromise or accidental exposure of the
  PII key does not expose fleet telemetry, audit logs, or payment refs
- **Audit granularity:** Each CMK generates separate CloudTrail events,
  enabling per-classification key usage reports for POPIA and PCI-DSS
  auditors
- **Regulatory evidence:** Auditors can see that PII data and payment
  data are encrypted under separate, independently controlled keys

## Consequences

**Positive:**

- Full key separation aligned to ISO 27001 and PCI-DSS requirements
- Per-classification audit trail (who decrypted PII and when)
- Payment CMK can be placed under dual-control MRK for PCI scope isolation
- Audit log CMK owned by separate AWS account prevents production
  account compromise from destroying audit evidence

**Negative / Trade-offs:**

- Cost: $1/CMK/month × 5 = $5/month (negligible, justified)
- Terraform complexity: each resource must reference the correct key ARN
  by classification — enforced through module outputs with named variables
  (pii_key_arn, payment_key_arn, etc.) to prevent misconfiguration

## Alternatives Considered

| Option | Why Rejected |
|--------|-------------|
| Single CMK for all data | Violates PCI-DSS key separation; single key compromise exposes all encrypted data; cannot produce per-classification audit trail for POPIA |
| AWS-managed keys only | Cannot customise key policy; AWS retains ability to decrypt; does not satisfy POPIA data processor requirement for encryption key control by the responsible party |
| Two keys (PII/Non-PII) | Insufficient granularity — PCI-DSS requires payment key separation from general PII; audit logs must be independently controlled |

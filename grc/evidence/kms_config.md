# KMS Configuration Evidence
## Avis Fleet & Mobility Platform

> **Purpose:** Evidence artifact for POPIA s19 and ISO 27001 A.8.24
> demonstrating that all personal information is encrypted using
> Customer Managed Keys with enforced rotation and restricted access.
>
> **Auditor note:** The Terraform source of truth for all key
> configurations is `terraform/modules/kms_key_set/main.tf`

---

## Key Inventory

| Key Alias | Classification Tier | Data Types Protected | Rotation | POPIA Scope |
|-----------|-------------------|---------------------|----------|-------------|
| `alias/avis/pii` | Tier 1 — PII Critical | SA ID numbers, passport numbers, home addresses, driver's licence numbers | Annual (automatic) | Yes — s19 |
| `alias/avis/payment` | Tier 2 — Payment | Masked PAN references, transaction IDs | Annual (automatic) | Partial — s19 |
| `alias/avis/fleet` | Tier 3 — Fleet Telemetry | GPS coordinates, VIN numbers, speed data | Annual (automatic) | No |
| `alias/avis/logs` | Tier 4 — Audit Logs | CloudTrail events, VPC Flow Logs, application audit events | Annual (automatic) | No |
| `alias/avis/secrets` | Tier 5 — Secrets | Database credentials, API keys, certificates | Annual (automatic) | No |
| `alias/avis/biometric` | Special Category — Biometric | Passport scans, counter photos, Rekognition face comparison inputs | Annual (automatic) | Yes — s19 special category |

---

## Key Policy Summary

### alias/avis/pii
Authorised decrypt principals:
- `rds.amazonaws.com` — Aurora database encryption
- `lambda.amazonaws.com` — booking service Lambda only
- `s3.amazonaws.com` — PII document storage
- `arn:aws:iam::ACCOUNT:role/avis-zero-trust-booking-service-role`

Explicitly denied:
- All other principals via explicit Deny condition in key policy
- Prevents lateral access from fleet or admin roles

### alias/avis/biometric
Authorised decrypt principals:
- `rekognition.amazonaws.com` — face comparison only
- `arn:aws:iam::ACCOUNT:role/avis-zero-trust-foreign-verification-role`

Explicitly denied:
- All other principals — biometric data cannot be
  decrypted by booking service, fleet service, or
  any other application role

---

## Compliance Mapping

| Obligation | How This Evidence Satisfies It |
|-----------|-------------------------------|
| POPIA s19 — security safeguards | 6 CMKs encrypt all personal data at rest; key policies enforce least-privilege access to decryption; automatic rotation prevents key age risk |
| POPIA s19 — biometric special category | Dedicated `alias/avis/biometric` key with restricted policy means biometric data is cryptographically isolated from all other data tiers |
| ISO 27001 A.8.24 — use of cryptography | Documented key hierarchy; rotation enforced; no weak algorithms; key custodianship via IAM key policies; PCI-DSS key separation for payment tier |
| ISO 27001 A.10.1.1 — cryptographic controls policy | This document IS the cryptographic controls policy evidence |

---

## How to Verify (Auditor Instructions)
```bash
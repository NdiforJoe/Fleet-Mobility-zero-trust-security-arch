# Data Security Requirements
## Handoff Document — Security Architect to Data Architect
### Avis Fleet & Mobility Platform

> **Document type:** Non-Functional Security Requirements (NFRs)
> **From:** Security Architect
> **To:** Data Architect + Data Engineering Teams
> **Status:** Approved — schema and storage designs must satisfy
> these requirements before any data pipeline goes to staging
>
> **Compliance:** POPIA s19, GDPR Art.32, ISO 27001 A.8.24,
> PCI-DSS Requirement 3

---

## Data Classification Tiers

Every field in every table must be classified before
the schema is finalised. Use this tier table:

| Tier | Classification | Examples | KMS Key | Retention |
|------|---------------|---------|---------|-----------|
| 1 | PII Critical | SA ID, passport, address, driver's licence | `alias/avis/pii` | 7 years |
| 2 | PII Standard | Name, email, phone | `alias/avis/pii` | 7 years |
| 3 | Payment | Masked PAN, transaction ID | `alias/avis/payment` | 7 years |
| 4 | Fleet | GPS coordinates, VIN, speed | `alias/avis/fleet` | 2 years |
| 5 | Operational | Session tokens, audit events | `alias/avis/logs` | 1 year |
| Special | Biometric | Passport scans, counter photos | `alias/avis/biometric` | 90 days |

---

## SR-DATA-001 — Aurora Schema Encryption

**Severity:** CRITICAL
**STRIDE ref:** T-005 (Information Disclosure)
**SABSA layer:** Component
**Compliance:** POPIA s19, ISO 27001 A.8.24

Aurora cluster must be encrypted at rest using
`alias/avis/pii` CMK. Encryption must be enabled
at cluster creation — it cannot be added afterward.
```sql
-- Table design: classify every column
CREATE TABLE customers (
  customer_id     UUID PRIMARY KEY,
  -- Tier 1 PII Critical
  sa_id_encrypted     BYTEA,    -- encrypted at app layer before insert
  passport_encrypted  BYTEA,    -- encrypted at app layer before insert
  address_encrypted   BYTEA,    -- encrypted at app layer before insert
  -- Tier 2 PII Standard
  full_name       VARCHAR(200), -- Aurora KMS handles at rest
  email           VARCHAR(320), -- Aurora KMS handles at rest
  phone           VARCHAR(20),
  -- Identity document fields (SR-DATA-007)
  id_document_type    VARCHAR(20)  NOT NULL,
  id_document_number  VARCHAR(50)  NOT NULL,
  id_issuing_country  CHAR(2)      NOT NULL,
  id_expiry_date      DATE         NOT NULL,
  licence_type        VARCHAR(30),
  -- Audit fields
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  popia_consent   BOOLEAN     NOT NULL DEFAULT FALSE,
  consent_at      TIMESTAMPTZ
);
```

Tier 1 fields (sa_id, passport, address) must be
encrypted at the application layer BEFORE insertion,
in addition to Aurora's KMS encryption at rest.
This provides double encryption for the most sensitive fields.

**Definition of Done:**
- [ ] Aurora cluster created with `alias/avis/pii` KMS key
- [ ] Terraform: `storage_encrypted = true` + `kms_key_id`
- [ ] Tier 1 fields encrypted at application layer
- [ ] No Tier 1 PII in plaintext in any column
- [ ] RDS snapshot encryption verified

---

## SR-DATA-002 — S3 Bucket Encryption per Classification

**Severity:** CRITICAL
**STRIDE ref:** T-005, T-011
**SABSA layer:** Component

Every S3 bucket must use SSE-KMS with the correct
CMK for its classification tier. SSE-S3 (AES-256)
is not acceptable for PII or biometric data.
```hcl
# CORRECT — SSE-KMS with classification-specific key
resource "aws_s3_bucket_server_side_encryption_configuration" "pii_docs" {
  bucket = aws_s3_bucket.pii_documents.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.pii_key_arn
    }
    bucket_key_enabled = true
  }
}

# INCORRECT — wrong key for PII bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "pii_docs" {
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # ← not acceptable for PII
    }
  }
}
```

Bucket naming convention must reflect classification:
- `avis-pii-documents-{account}` → `alias/avis/pii`
- `avis-id-documents-foreign-{account}` → `alias/avis/biometric`
- `avis-fleet-telemetry-{account}` → `alias/avis/fleet`
- `avis-audit-logs-{account}` → `alias/avis/logs`

**Definition of Done:**
- [ ] All S3 buckets use SSE-KMS not SSE-S3
- [ ] Bucket encryption key matches data classification
- [ ] Public access block enabled on all buckets
- [ ] AWS Config rule: s3-bucket-server-side-encryption-enabled

---

## SR-DATA-003 — Data Minimisation

**Severity:** HIGH
**STRIDE ref:** T-009 (Information Disclosure to partners)
**Compliance:** GDPR Art.5(1)(c), POPIA s11

No table should store a field that is not required
for a documented business purpose. Before adding any
new column, the Data Architect must confirm:
```
1. WHY is this field needed?
   (specific business process or legal obligation)

2. WHO will access it?
   (specific role — not "the application")

3. HOW LONG is it needed?
   (retention period per grc/popia_data_inventory.md)

4. WHAT happens when the purpose ends?
   (deletion process)
```

Fields that cannot answer all four questions
must not be added to the schema.

**Definition of Done:**
- [ ] Data dictionary completed for every table
- [ ] Every column has documented business purpose
- [ ] Macie scan confirms no unexpected PII in non-PII buckets
- [ ] Quarterly data minimisation review in ISMS calendar

---

## SR-DATA-004 — Retention and Deletion

**Severity:** HIGH
**STRIDE ref:** T-005
**Compliance:** POPIA s14, GDPR Art.17

Retention periods from `grc/popia_data_inventory.md`
must be enforced automatically — not manually.
```
Aurora (booking records + PII):
  Soft-delete at request: set deleted_at = NOW()
  Hard-delete: Lambda scheduled job runs weekly,
  permanently deletes records where
  deleted_at < NOW() - INTERVAL '7 years'

DynamoDB (sessions):
  TTL attribute: session_expiry (Unix timestamp)
  Set to NOW() + 900 seconds (15 minutes)
  DynamoDB TTL process deletes automatically

S3 (biometric documents):
  Lifecycle rule: expire after 90 days
  No manual deletion required

S3 (audit logs — CloudTrail):
  Object Lock COMPLIANCE: 7 years
  Cannot be deleted — do not add lifecycle rule

S3 (fleet telemetry):
  Lifecycle rule: expire after 2 years
  Transition to Glacier after 90 days
```

**Definition of Done:**
- [ ] Aurora: soft-delete column on all PII tables
- [ ] Aurora: scheduled Lambda deletion job tested
- [ ] DynamoDB: TTL attribute on session table
- [ ] S3 biometric: 90-day lifecycle rule configured
- [ ] S3 fleet: 2-year lifecycle + Glacier transition
- [ ] Deletion tested end-to-end in dev environment

---

## SR-DATA-005 — Aurora Backup Encryption

**Severity:** HIGH
**STRIDE ref:** T-005
**Compliance:** ISO 27001 A.8.24

Aurora automated backups and manual snapshots
inherit the cluster KMS key (`alias/avis/pii`).
Cross-account snapshot copies must re-encrypt
with the destination account's CMK.
```hcl
resource "aws_db_cluster" "avis_main" {
  # ...
  storage_encrypted               = true
  kms_key_id                      = var.pii_key_arn
  backup_retention_period         = 35  # 35 days automated backup
  preferred_backup_window         = "02:00-03:00"  # 2am SAST
  deletion_protection             = true
  skip_final_snapshot             = false
  final_snapshot_identifier       = "avis-final-snapshot"
}
```

**Definition of Done:**
- [ ] `storage_encrypted = true` in Terraform
- [ ] Backup retention = 35 days
- [ ] Snapshot encryption verified via AWS console
- [ ] DR snapshot copy tested with re-encryption

---

## SR-DATA-006 — DynamoDB Row-Level Access Control

**Severity:** HIGH
**STRIDE ref:** T-013 (Session token disclosure)
**SABSA layer:** Component

The session management DynamoDB table must enforce
row-level access control so that each service role
can only access records belonging to its own
partition key scope.
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ],
    "Resource": "arn:aws:dynamodb:*:*:table/avis-sessions",
    "Condition": {
      "ForAllValues:StringEquals": {
        "dynamodb:LeadingKeys": ["${aws:PrincipalTag/customer_id}"]
      }
    }
  }]
}
```

This means a Lambda function processing
customer A's request cannot read or write
customer B's session record — even if it
has the correct table-level permission.

**Definition of Done:**
- [ ] IAM condition `dynamodb:LeadingKeys` on session table role
- [ ] Integration test: role for customer A cannot read customer B record
- [ ] DynamoDB encryption with `alias/avis/pii` CMK
- [ ] GuardDuty: DynamoDB scan anomaly detection enabled

---

## SR-DATA-007 — Flexible Identity Document Schema

**Severity:** HIGH
**STRIDE ref:** T-016, T-017 (identity fraud)
**SABSA layer:** Component
**Added:** Walk-in SA + foreign customer scenarios

The customer identity schema must support multiple
document types. A single `id_number VARCHAR(13)` field
assuming SA ID format is not acceptable.
```sql
-- CORRECT schema — supports all document types
ALTER TABLE customers ADD COLUMN IF NOT EXISTS
  id_document_type    VARCHAR(20) NOT NULL
    CHECK (id_document_type IN (
      'SA_ID', 'PASSPORT', 'IDP',
      'GCC_NATIONAL_ID', 'EU_NATIONAL_ID'
    )),
  id_document_number  VARCHAR(50) NOT NULL,
  id_issuing_country  CHAR(2)     NOT NULL,
  id_expiry_date      DATE        NOT NULL,
  licence_type        VARCHAR(30)
    CHECK (licence_type IN (
      'SA_LICENCE', 'FOREIGN_WITH_IDP', NULL
    )),
  entry_date_sa       DATE,  -- for IDP validity check (< 366 days)
  verification_status VARCHAR(20) DEFAULT 'PENDING'
    CHECK (verification_status IN (
      'PENDING', 'VERIFIED', 'FAILED', 'MANUAL_REVIEW'
    )),
  verification_method VARCHAR(30),  -- DHA_API, JUMIO, MANUAL
  verification_score  DECIMAL(5,2); -- Rekognition similarity score
```

Input validation rules per type are defined
in SR-APP-003 (App Architect NFRs).

**Definition of Done:**
- [ ] Schema migration creates all new columns
- [ ] CHECK constraints enforce valid document types
- [ ] SA ID column retained for backwards compatibility
  but deprecated — new code uses id_document_type
- [ ] Data migration script updates existing records
  with id_document_type = 'SA_ID'
- [ ] Integration test: booking with PASSPORT type succeeds
- [ ] Integration test: booking with expired IDP fails
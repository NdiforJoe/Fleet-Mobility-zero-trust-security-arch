# Data Security NFRs
## Handoff to: Data Architect
## From: Security Architect
## Version: 1.0 | Status: Approved

---

## Data Classification Tiers

All data assets must be classified before any design decision is made.
Encryption key, retention policy, and access control are all determined
by classification.

| Tier | Examples | KMS Key | Retention | Access |
|------|---------|---------|-----------|--------|
| **Tier 1 — PII Critical** | SA ID number, driver's licence, home address, bank account reference | `alias/avis/pii` | 7 years | Booking service only (IAM condition) |
| **Tier 2 — PII Standard** | Name, email, phone number, vehicle preference | `alias/avis/pii` | 7 years | Booking service + customer portal |
| **Tier 3 — Payment Reference** | Masked PAN (last 4), transaction ID, payment gateway token | `alias/avis/payment` | 7 years (PCI-DSS) | Payment service only |
| **Tier 4 — Fleet Data** | Vehicle VIN, GPS coordinates, telemetry readings | `alias/avis/fleet` | 2 years | Fleet service + analytics |
| **Tier 5 — Operational** | Application logs, metrics, health data | `alias/avis/logs` | 1 year | SOC + DevOps |

---

## Data NFR Reference Table

| ID | Requirement | Applies To | Severity | Compliance |
|----|-------------|-----------|----------|-----------|
| SR-DATA-001 | All Tier 1 and Tier 2 PII fields stored in Aurora must use column-level encryption with the `avis/pii` KMS CMK. The application layer must decrypt only the fields needed for each operation — no bulk decryption of unneeded columns. | Aurora PostgreSQL | CRITICAL | POPIA s19, ISO A.8.24 |
| SR-DATA-002 | All S3 buckets storing PII or payment data must have: SSE-KMS with the appropriate CMK, bucket versioning enabled, public access block enabled (all four settings), and bucket policies denying `s3:PutObject` without server-side encryption. | S3 buckets | CRITICAL | POPIA s19, ISO A.8.24 |
| SR-DATA-003 | API responses must return only the fields required by the consuming service. No `SELECT *` queries in production code. Field-level filtering must be applied at the application layer before returning data to API consumers. Integration partners receive only fields specified in their Data Processing Agreement. | All services | HIGH | GDPR Art.5(1)(c), POPIA s10 |
| SR-DATA-004 | Customer PII must be deleted or anonymised within 7 years of the customer's last booking (POPIA retention obligation). An automated S3 lifecycle policy and DynamoDB TTL must enforce this. The deletion process must log a confirmation event to the audit trail. | Aurora, S3, DynamoDB | HIGH | POPIA s14 |
| SR-DATA-005 | Aurora automated backups must be encrypted with the `avis/pii` CMK. Backup restore must be tested monthly in an isolated non-production account. RTO target: 4 hours. RPO target: 1 hour. | Aurora PostgreSQL | HIGH | ISO A.8.13, NIST CP-9 |
| SR-DATA-006 | DynamoDB session table: row-level access control using `dynamodb:LeadingKeys` condition in IAM policy — each service may only access records with its own partition key prefix. Sessions must expire via TTL after 15 minutes. | DynamoDB | HIGH | T-013 (Info Disclosure) |

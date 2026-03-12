# POPIA Personal Information Data Inventory

## Avis Fleet & Mobility Platform

> **Purpose:** Documents all personal information processed by the
> platform in accordance with POPIA s14 (data subject rights) and
> ISO 27001 A.8.12 (data leakage prevention).
>
> **Review cycle:** Quarterly or upon any new data collection being introduced

---

## What is Personal Information Under POPIA

POPIA defines personal information as information relating to
an identifiable, living, natural person (or juristic person).
The following inventory documents every personal information
field collected, stored, or processed by the Avis platform.

---

## Data Inventory

| Field | Classification | Storage Location | Encryption | Retention | Data Subject Right | POPIA Basis |
|-------|---------------|-----------------|------------|-----------|-------------------|-------------|
| SA ID number | Tier 1 — PII Critical | Aurora PostgreSQL | `alias/avis/pii` | 7 years | Access, Correction, Deletion | Contract (rental agreement) |
| Passport number | Tier 1 — PII Critical | Aurora PostgreSQL | `alias/avis/pii` | 7 years | Access, Correction, Deletion | Contract (rental agreement) |
| Full name | Tier 1 — PII Critical | Aurora PostgreSQL | `alias/avis/pii` | 7 years | Access, Correction, Deletion | Contract |
| Home address | Tier 1 — PII Critical | Aurora PostgreSQL | `alias/avis/pii` | 7 years | Access, Correction, Deletion | Contract |
| Driver's licence number | Tier 1 — PII Critical | Aurora PostgreSQL | `alias/avis/pii` | 7 years | Access, Correction, Deletion | Legal obligation (NRTA) |
| Driver's licence expiry | Tier 1 — PII Critical | Aurora PostgreSQL | `alias/avis/pii` | 7 years | Access, Correction | Legal obligation (NRTA) |
| Email address | Tier 2 — PII Standard | Aurora PostgreSQL + Cognito | `alias/avis/pii` | 7 years | Access, Correction, Deletion | Consent + Contract |
| Mobile number | Tier 2 — PII Standard | Aurora PostgreSQL + Cognito | `alias/avis/pii` | 7 years | Access, Correction, Deletion | Consent + Contract |
| Booking history | Tier 2 — PII Standard | Aurora PostgreSQL | `alias/avis/pii` | 7 years | Access, Portability | Contract |
| Payment reference (masked PAN) | Tier 2 — Payment | Aurora PostgreSQL | `alias/avis/payment` | 7 years | Access | Contract + PCI-DSS |
| GPS location history | Tier 3 — Fleet | DynamoDB + S3 | `alias/avis/fleet` | 2 years | Access, Deletion | Contract (rental terms) |
| Passport scan (image) | Special Category — Biometric | S3 `id-documents/foreign/` | `alias/avis/biometric` | 90 days post-rental | Access, Deletion | Contract + Legal obligation |
| Counter photo (face image) | Special Category — Biometric | S3 `id-documents/foreign/` | `alias/avis/biometric` | 90 days post-rental | Access, Deletion | Contract + Legal obligation |
| POPIA consent timestamp | Operational | Aurora PostgreSQL + Cognito | `alias/avis/pii` | 7 years | Access | Legal obligation |
| Session tokens (hashed) | Operational | DynamoDB | `alias/avis/pii` | 15 minutes (TTL) | N/A — auto-expire | Contract |
| Device fingerprint | Operational | Cognito + DynamoDB | `alias/avis/pii` | Duration of account | Deletion | Contract |

---

## Data Subject Rights Procedures

| Right | How to Exercise | SLA | AWS Implementation |
|-------|----------------|-----|-------------------|
| Right to Access (s23) | Customer portal: `/api/profile` GET endpoint | 30 days | Lambda queries Aurora + DynamoDB + S3 metadata per customer ID |
| Right to Correction (s24) | Customer portal: `/api/profile` PATCH endpoint | 30 days | Lambda UPDATE on Aurora customer record; CloudTrail audit log |
| Right to Deletion (s24) | Customer portal: `/api/profile/delete` DELETE endpoint | 30 days | Cognito DeleteUser + Aurora soft-delete + S3 lifecycle immediate expiry + DynamoDB TTL set to now |
| Right to Portability (GDPR Art.20) | Customer portal: `/api/profile/export` GET endpoint | 30 days | Lambda packages all fields as JSON; rate-limited 1 per 24h; requires step-up MFA |
| Right to Object (s11) | Customer support channel | 30 days | Manual process — compliance team reviews; documented in ISMS |

---

## Retention Schedule

| Data Category | Retention Period | Legal Basis | Deletion Method |
|--------------|-----------------|-------------|-----------------|
| Booking records + PII | 7 years | SARS tax obligation; Consumer Protection Act | Aurora soft-delete → hard-delete at 7 years via Lambda scheduled job |
| Biometric data (passport + photo) | 90 days post-rental completion | Minimum necessary for fraud investigation | S3 lifecycle rule: expire after 90 days; alias/avis/biometric key decrypt disabled after expiry |
| GPS location history | 2 years | Fleet management + insurance obligation | DynamoDB TTL + S3 lifecycle |
| Session tokens | 15 minutes | Operational | DynamoDB TTL automatic |
| Audit logs (CloudTrail) | 7 years | ISO 27001 A.12.4; POPIA s19 | S3 Object Lock COMPLIANCE — cannot be deleted early |

---

## Third Parties Who Receive Personal Information

| Third Party | Data Shared | Legal Basis | Safeguard |
|------------|-------------|-------------|-----------|
| Airline loyalty partners | Booking reference, customer name only | Contract (loyalty programme) | API field filtering strips all other PII; partner DPA in place |
| Home Affairs (DHA) | SA ID number | Legal obligation (identity verification) | One-way verification only — DHA confirms valid/invalid, does not receive full profile |
| Jumio / Onfido | Passport MRZ data | Contract (fraud prevention) | Processor DPA; GDPR-compliant; data not retained by Jumio beyond verification |
| AWS Rekognition (eu-west-1) | Passport photo (biometric) | Contract; adequacy (GDPR/Ireland) | Stateless call; no retention; see `grc/evidence/rekognition_transfer_justification.md` |

---

## Document Control

| Field | Value |
|-------|-------|
| Document owner | Security Architect + Compliance Manager |
| Last reviewed | 2025-Q1 |
| Next review | 2025-Q3 |
| Approved by | CISO |
| Changes trigger | Any new data field collected; new third party receiving data; new storage location |

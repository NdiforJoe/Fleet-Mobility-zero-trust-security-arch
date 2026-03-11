# Cross-Border Transfer Justification
## Rekognition Face Comparison — af-south-1 to eu-west-1

> **Purpose:** Evidence artifact for POPIA s26 cross-border transfer
> obligation. Documents the legal basis and technical safeguards for
> processing foreign national passport photos via AWS Rekognition
> in eu-west-1 (Ireland).
>
> **Regulation:** POPIA s72 (cross-border transfer of personal information)

---

## Background

AWS Rekognition is not available in af-south-1 (Cape Town).
The foreign customer identity verification workflow (T-017)
requires face comparison between a passport photo and a
live counter photo to mitigate identity fraud risk.

This document justifies the cross-border processing under POPIA s26.

---

## Transfer Details

| Field | Value |
|-------|-------|
| Data type transferred | Passport photo (biometric — special category) |
| Source region | af-south-1 (Cape Town, South Africa) |
| Destination region | eu-west-1 (Ireland, European Union) |
| Purpose | Face comparison only — verify passport photo matches person at counter |
| AWS service used | Amazon Rekognition CompareFaces API |
| Data retained in eu-west-1 | NO — only similarity score returned |
| Transfer mechanism | AWS internal API call (Lambda to Rekognition endpoint) |
| Frequency | Only during walk-in foreign customer verification |

---

## Legal Basis Under POPIA s26

POPIA s26 permits cross-border transfer where the destination
country provides an adequate level of protection for personal
information equivalent to POPIA.

**Adequacy basis:** Ireland is a member state of the European Union
and is subject to the General Data Protection Regulation (GDPR).
The GDPR provides comprehensive data protection obligations that
are broadly equivalent to or exceed POPIA protections.

This adequacy determination is consistent with the approach
taken by the South African Information Regulator for transfers
to GDPR-regulated jurisdictions.

---

## Technical Safeguards
```
WHAT IS TRANSFERRED:
Passport photo (JPEG, max 5MB) from S3 in af-south-1
sent as base64 payload to Rekognition in eu-west-1

WHAT IS RETURNED:
{
  "FaceMatches": [{
    "Similarity": 94.7,
    "Face": { ... bounding box only, no PII }
  }]
}

WHAT IS NOT RETAINED IN eu-west-1:
- No passport photo stored in eu-west-1
- No customer name, ID number, or booking data
- No Rekognition collection created
- Stateless API call only

ENCRYPTION IN TRANSIT:
- TLS 1.3 for Lambda to Rekognition API call
- Passport photo encrypted with alias/avis/biometric
  in af-south-1 before transfer

AUDIT TRAIL:
- CloudTrail logs every Rekognition API call
- Step Functions execution log records:
  verification timestamp, similarity score,
  agent ID, booking ID
- No passport photo content in audit logs
```

---

## Data Flow Diagram
```
Branch Counter (OR Tambo)
         |
         | Naledi photographs passport
         v
S3 af-south-1 (alias/avis/biometric encrypted)
         |
         | Lambda reads photo
         v
Lambda af-south-1
         |
         | CompareFaces API call (TLS 1.3)
         | Photo sent as base64 payload
         v
Rekognition eu-west-1 (Ireland)
         |
         | Returns similarity score only
         | Photo NOT stored
         v
Lambda af-south-1
         |
         | Score > 90% = PASS
         | Score 80-90% = Manual review
         | Score < 80% = FAIL
         v
Step Functions — update booking verification status
         |
         v
CloudTrail — log verification result
```

---

## AWS Data Processing Agreement

AWS Ireland Limited (operator of eu-west-1) processes data
under the AWS Customer Agreement and AWS Data Processing
Addendum, which incorporates GDPR-compliant Standard
Contractual Clauses for data transfers.

Reference: https://aws.amazon.com/agreement/
AWS DPA: https://aws.amazon.com/compliance/gdpr-center/

---

## Review and Approval

| Field | Value |
|-------|-------|
| Document owner | Security Architect |
| Approved by | CISO, Legal/Compliance |
| Review cycle | Annual or upon change to Rekognition service availability in af-south-1 |
| Next review date | 2026-Q1 |
| Action if Rekognition becomes available in af-south-1 | Update Lambda to use af-south-1 endpoint; this document becomes obsolete; update compliance matrix POPIA s26 row |
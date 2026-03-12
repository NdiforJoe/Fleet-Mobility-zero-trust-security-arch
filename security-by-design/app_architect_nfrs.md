# Application Security Requirements
## Handoff Document — Security Architect to App Architect
### Avis Fleet & Mobility Platform

> **Document type:** Non-Functional Security Requirements (NFRs)
> **From:** Security Architect
> **To:** Application Architect + Development Teams
> **Status:** Approved — must be implemented before any endpoint
> goes to staging
>
> **How to use this document:**
> Each SR-APP requirement is testable. The Definition of Done
> for every user story must include evidence that the relevant
> SR-APP controls are satisfied. Security Architect signs off
> before production deployment.

---

## SR-APP-001 — JWT Validation (Zero-Trust Enforcement)

**Severity:** CRITICAL
**STRIDE ref:** T-001 (Spoofing), T-002 (Elevation of Privilege)
**SABSA layer:** Logical → Component

Every API endpoint — without exception — must validate the
incoming JWT using the Lambda authoriser. The authoriser
must check all five of the following claims on every request.
Failure of any single check must return HTTP 401 immediately
with no additional detail in the response body.
```
CLAIM 1: RS256 signature
         Verify using Cognito JWKS endpoint
         Reject if algorithm is not RS256
         Never accept HS256 or none algorithm

CLAIM 2: Expiry (exp)
         Token must not be expired
         15-minute maximum TTL enforced by Cognito
         Clock skew tolerance: 30 seconds maximum

CLAIM 3: Audience (aud)
         Must match this application's Cognito client ID
         Reject tokens issued for other client IDs

CLAIM 4: Issuer (iss)
         Must match:
         https://cognito-idp.af-south-1.amazonaws.com/POOL_ID
         Reject tokens from any other issuer

CLAIM 5: Device fingerprint
         custom:device_fingerprint claim must match
         the fingerprint registered at login
         Mismatch = possible token theft → reject + alert SOC
```

**Definition of Done:**
- [ ] Lambda authoriser unit tests cover all 5 failure scenarios
- [ ] Integration test: expired token returns 401
- [ ] Integration test: wrong audience returns 401
- [ ] Integration test: missing device fingerprint returns 401
- [ ] CloudWatch alarm fires on >10 authoriser rejections/minute

---

## SR-APP-002 — Step-Up MFA for High-Risk Actions

**Severity:** CRITICAL
**STRIDE ref:** T-001 (Spoofing), T-002 (Elevation of Privilege)
**SABSA layer:** Logical → Component

The following endpoints require a `step_up_mfa` claim in the JWT
issued within the last 10 minutes. A valid base JWT alone is
insufficient. Return HTTP 403 with body
`{"error": "step_up_mfa_required"}` if the claim is absent
or older than 10 minutes.
```
Endpoints requiring step-up MFA:
POST   /api/payments/*
PUT    /api/profile/payment-methods
GET    /api/profile/export          (GDPR Art.20 portability)
DELETE /api/profile                 (account deletion)
PUT    /api/profile/id-documents    (document update)
```

**Rationale:** Even if a customer's base session token is stolen,
the attacker cannot complete a payment or export PII without
the customer's MFA device. This limits the blast radius of
T-001 for high-value actions.

**Definition of Done:**
- [ ] Payment endpoint returns 403 without step_up_mfa claim
- [ ] step_up_mfa claim older than 10 minutes is rejected
- [ ] Frontend prompts MFA re-authentication before payment flow
- [ ] CloudTrail logs every step-up MFA challenge and result

---

## SR-APP-003 — Input Validation per Document Type

**Severity:** HIGH
**STRIDE ref:** T-003 (Tampering), T-005 (SQL Injection)
**SABSA layer:** Component
**Added:** Walk-in customer + foreign national scenarios

Identity document fields must be validated per document type.
A single generic string validator is insufficient — each type
has a specific format that must be enforced server-side.
```
DOCUMENT TYPE      FORMAT RULE                    EXAMPLE
────────────────────────────────────────────────────────
SA_ID              Exactly 13 digits              9001015009087
                   Luhn check on last digit
                   First 6 digits = valid date

PASSPORT           6-20 alphanumeric characters   AB1234567
                   Issuing country code required  Must match id_issuing_country

IDP                Format varies by country       Must accompany foreign licence
                   Expiry date required            Must not be expired
                   Must include issuing country

SA_LICENCE         8-13 alphanumeric              WP123456789
                   Must not be expired

FOREIGN_LICENCE    Alphanumeric, 5-20 chars       Must accompany IDP
                   Issuing country required
                   days_in_sa check: < 366 days
```

All validation must occur server-side in the Lambda handler.
Client-side validation is UX only — never trusted for security.
Parameterised queries must be used for all database operations.
No dynamic SQL construction permitted.

**Definition of Done:**
- [ ] Unit tests for each document type including boundary cases
- [ ] SA ID with invalid Luhn digit returns 400
- [ ] Foreign licence without IDP returns 400
- [ ] days_in_sa > 365 returns 400 with specific error code
- [ ] WAF SQL injection rule set enabled on API Gateway

---

## SR-APP-004 — Error Handling

**Severity:** HIGH
**STRIDE ref:** T-005 (Information Disclosure)
**SABSA layer:** Component

Application errors must never expose internal system details
to API consumers. Stack traces, database error messages,
internal ARNs, and file paths are classified as sensitive
operational information.
```
CORRECT error response:
HTTP 500
{
  "error": "internal_server_error",
  "request_id": "abc-123-def"  ← CloudWatch correlation ID only
}

INCORRECT error response (never do this):
HTTP 500
{
  "error": "PG::UniqueViolation: ERROR: duplicate key value
            violates unique constraint 'customers_pkey'
            DETAIL: Key (id)=(12345) already exists.",
  "stack": "at QueryExecutor.execute (/app/db/query.js:45)"
}
```

All errors must be logged internally with full detail
to CloudWatch Logs. The correlation request_id allows
the SOC to retrieve full error context from logs
without exposing it to the API consumer.

**Definition of Done:**
- [ ] All Lambda handlers have try/catch returning generic errors
- [ ] Integration test: trigger DB error, verify no stack trace in response
- [ ] CloudWatch logs show full error detail with request_id
- [ ] Penetration test: error enumeration returns no useful detail

---

## SR-APP-005 — Secrets Management

**Severity:** CRITICAL
**STRIDE ref:** T-010 (Elevation of Privilege)
**SABSA layer:** Component

No secrets, credentials, API keys, or connection strings
may appear in:
- Application source code
- Environment variables in Lambda configuration
- Docker image layers
- CloudFormation/Terraform outputs (unless marked sensitive)
- CloudWatch Logs
- Git history (including deleted commits)

All secrets must be retrieved from AWS Secrets Manager
at runtime using the Lambda execution role. The role
must have GetSecretValue permission only on the specific
secret ARNs it requires — not `secretsmanager:*`.
```python
# CORRECT — retrieve at runtime
import boto3
client = boto3.client('secretsmanager')
secret = client.get_secret_value(
    SecretId='avis/prod/aurora/booking-service'
)

# INCORRECT — hardcoded credential
DB_PASSWORD = "avis2024secure!"  # ← immediate security incident
```

Pre-commit hooks must scan for secrets before any
commit reaches the repository. See Phase 9 CI/CD
pipeline for git-secrets and truffleHog configuration.

**Definition of Done:**
- [ ] No secrets in Lambda environment variables
- [ ] IAM role has GetSecretValue on specific ARN only
- [ ] Pre-commit hook blocks commits containing secrets
- [ ] Secrets Manager rotation configured (30 days)
- [ ] Snyk or truffleHog scan passes in CI pipeline

---

## SR-APP-006 — Audit Logging Format

**Severity:** HIGH
**STRIDE ref:** T-008 (Repudiation), T-011 (Tampering)
**SABSA layer:** Operational
**Compliance:** POPIA s19, ISO 27001 A.12.4

Every application event involving personal information
must produce a structured audit log entry in the
following format. Unstructured log lines are not
acceptable as audit evidence.
```json
{
  "timestamp": "2025-01-15T14:23:07.123Z",
  "event_type": "PII_ACCESS",
  "request_id": "abc-123-def",
  "user_id": "cognito-sub-uuid",
  "user_type": "customer|staff|system",
  "branch_code": "OR-TAMBO|null",
  "action": "VIEW_BOOKING|UPDATE_PROFILE|EXPORT_DATA|DELETE_ACCOUNT",
  "resource_type": "booking|customer_profile|payment|document",
  "resource_id": "booking-uuid",
  "pii_fields_accessed": ["email", "sa_id", "address"],
  "outcome": "SUCCESS|FAILURE|DENIED",
  "ip_address": "10.1.0.45",
  "user_agent": "AvisMobile/2.1 iOS/17.0"
}
```

PII field values must NEVER appear in audit logs.
Only field names are logged — not the actual SA ID number.
Logs are shipped to CloudWatch Logs and picked up by
CloudTrail for immutable storage in S3 Object Lock bucket.

**Definition of Done:**
- [ ] All Lambda handlers emit structured JSON logs
- [ ] pii_fields_accessed lists field names, not values
- [ ] CloudWatch log group retention set to 90 days minimum
- [ ] CloudTrail picks up application log group
- [ ] Log format validated by automated test in CI pipeline

---

## SR-APP-007 — Dependency Management

**Severity:** HIGH
**STRIDE ref:** T-012 (Tampering — supply chain)
**SABSA layer:** Component
**Compliance:** ISO 27001 A.8.7, A.8.25

All third-party dependencies must be pinned to exact
versions. Unpinned dependencies (`^1.2.3` or `~1.2.3`)
are not permitted in production Lambda packages.
```json
// CORRECT — exact version pin
"dependencies": {
  "aws-sdk": "2.1491.0",
  "jsonwebtoken": "9.0.2"
}

// INCORRECT — unpinned
"dependencies": {
  "aws-sdk": "^2.1.0",
  "jsonwebtoken": "~9.0.0"
}
```

Snyk dependency scanning must pass in CI pipeline
before any deployment to staging or production.
Critical vulnerabilities block deployment.
High vulnerabilities require Security Architect approval.

**Definition of Done:**
- [ ] All package.json/requirements.txt use exact versions
- [ ] Snyk scan integrated in CI pipeline
- [ ] Critical CVE = pipeline blocked
- [ ] High CVE = Security Architect approval gate
- [ ] Dependabot or Renovate configured for weekly updates

---

## SR-APP-008 — Session Management

**Severity:** HIGH
**STRIDE ref:** T-013 (Information Disclosure), T-015 (branch workstation)
**SABSA layer:** Component

Application sessions must enforce the following timeouts
to mitigate both remote session theft and physical
workstation exposure at branch counters.
```
CUSTOMER SESSIONS (mobile + web):
  Access token TTL:   15 minutes (Cognito enforced)
  Refresh token TTL:  1 day (rotates on every use)
  Idle timeout:       15 minutes of inactivity
  Maximum session:    8 hours (force re-authentication)

STAFF SESSIONS (branch counter):
  Access token TTL:   4 hours (IAM Identity Center enforced)
  Idle timeout:       5 minutes (T-015 mitigation)
  Screen lock:        60 seconds (Intune Group Policy)
  Maximum session:    8 hours (force re-authentication)
```

Session tokens must be hashed before storage in DynamoDB.
Plain-text session tokens in any storage medium constitute
a CRITICAL security incident.

**Definition of Done:**
- [ ] Cognito access token TTL = 15 minutes confirmed
- [ ] Application idle timeout enforces re-authentication at 5 min
- [ ] DynamoDB session store contains hashed tokens only
- [ ] Branch workstation idle lock tested at 60 seconds
- [ ] CloudWatch alarm: session count spike > 2x baseline

---

## SR-APP-009 — Data Portability Endpoint (GDPR Art.20)

**Severity:** HIGH
**STRIDE ref:** T-005 (Information Disclosure — must be own data only)
**SABSA layer:** Component
**Compliance:** GDPR Art.20, POPIA s14

EU customers have the right to request their personal data
in machine-readable format. This endpoint must be implemented
before the platform accepts bookings from EU nationals.
```
Endpoint:    GET /api/profile/export
Auth:        Valid JWT + step_up_mfa claim (SR-APP-002)
Rate limit:  1 request per customer per 24 hours
Response:    JSON (see schema below)
Audit log:   Every export logged with customer ID + timestamp
```
```json
{
  "export_generated_at": "2025-01-15T14:23:07Z",
  "customer_id": "uuid",
  "personal_information": {
    "full_name": "Maria Gonzalez",
    "email": "maria@email.es",
    "phone": "+34612345678",
    "address": "123 Calle Mayor, Madrid"
  },
  "identity_documents": [
    {
      "type": "PASSPORT",
      "issuing_country": "ES",
      "expiry_date": "2030-06-15"
    }
  ],
  "booking_history": [...],
  "consent_record": {
    "popia_consent": true,
    "consent_timestamp": "2025-01-10T09:00:00Z"
  }
}
```

The response must include the customer's OWN data only.
The Lambda must validate that the JWT sub claim matches
the requested customer ID before querying any data.
Cross-customer data access via this endpoint is a
CRITICAL security incident.

**Definition of Done:**
- [ ] Endpoint requires step_up_mfa claim
- [ ] JWT sub must match requested customer ID
- [ ] Rate limit: 1 per customer per 24 hours enforced
- [ ] Export logged to CloudTrail with customer ID
- [ ] Integration test: customer A cannot export customer B data
- [ ] Response time < 5 seconds for standard profile

---

## Security Sign-Off Checklist

Before any endpoint is promoted to production, the
Security Architect must confirm:

| Check | SR Reference | Verified By | Date |
|-------|-------------|-------------|------|
| JWT validation covers all 5 claims | SR-APP-001 | | |
| Step-up MFA on payment endpoints | SR-APP-002 | | |
| Document type validation server-side | SR-APP-003 | | |
| Error responses contain no internals | SR-APP-004 | | |
| No secrets in code or environment | SR-APP-005 | | |
| Audit logs in structured JSON format | SR-APP-006 | | |
| Dependencies pinned + Snyk passing | SR-APP-007 | | |
| Session timeouts enforced | SR-APP-008 | | |
| Data portability endpoint secured | SR-APP-009 | | |
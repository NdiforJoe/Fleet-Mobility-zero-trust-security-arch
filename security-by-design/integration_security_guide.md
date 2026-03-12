# Integration Security Requirements

## Handoff Document — Security Architect to Integration Architect

### Avis Fleet & Mobility Platform

> **Document type:** Integration Security Standards
> **From:** Security Architect
> **To:** Integration Architect + Integration Engineering Teams
> **Status:** Approved — all partner integrations must satisfy
> these standards before connection is established
>
> **Compliance:** POPIA s19, GDPR Art.5(1)(c), ISO 27001 A.13.1

---

## Integration Security Principles

Every integration with a third-party system must satisfy
four baseline principles before any data flows:

```text
PRINCIPLE 1: MINIMUM NECESSARY DATA
  Send only the fields the partner needs for
  their specific purpose. No bulk PII payloads.
  Each partner has a documented field list.

PRINCIPLE 2: DEDICATED CREDENTIALS
  Each partner has its own credentials.
  No shared API keys across partners.
  Compromise of one partner = no impact on others.

PRINCIPLE 3: ENCRYPTED TRANSIT
  TLS 1.3 minimum for all partner connections.
  No TLS 1.0 or 1.1 permitted.
  Certificate pinning for high-risk integrations.

PRINCIPLE 4: AUDITABLE
  Every partner API call must produce a
  structured audit log entry.
  Data sent to each partner must be reconstructable
  from audit logs for POPIA s23 breach investigation.
```text

---

## SR-INT-001 — TLS Enforcement

**Severity:** CRITICAL
**STRIDE ref:** T-003 (Tampering), T-009 (Information Disclosure)
**Compliance:** POPIA s19(2), ISO 27001 A.8.24

All outbound integration connections must use TLS 1.3.
TLS 1.2 is acceptable only where the partner cannot
support 1.3 and a documented exception is approved
by the Security Architect.

```python
# CORRECT — enforce TLS 1.3
import ssl
import urllib3

ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
ssl_context.minimum_version = ssl.TLSVersion.TLSv1_3
ssl_context.verify_mode = ssl.CERT_REQUIRED
ssl_context.check_hostname = True

# INCORRECT — default SSL context allows older versions
import requests
response = requests.get(partner_url)  # no TLS version enforcement
```text

**Definition of Done:**

- [ ] All partner Lambda functions use explicit TLS 1.3 context
- [ ] SSL Labs or testssl.sh scan confirms TLS 1.3 on all endpoints
- [ ] TLS version logged in integration audit log
- [ ] Exception process documented if partner requires TLS 1.2

---

## SR-INT-002 — Dedicated Partner Credentials

**Severity:** CRITICAL
**STRIDE ref:** T-009, T-010
**Compliance:** ISO 27001 A.5.17

Each partner integration must use credentials stored
in AWS Secrets Manager under a partner-specific path.
No shared credentials across partners.

```text
SECRET NAMING CONVENTION:
avis/integrations/{partner_name}/{credential_type}

EXAMPLES:
avis/integrations/airline-loyalty/api-key
avis/integrations/home-affairs-dha/client-cert
avis/integrations/jumio/api-secret
avis/integrations/onfido/webhook-secret

ROTATION:
All partner credentials rotated every 90 days.
Rotation Lambda triggers partner credential
update and verifies new credential before
retiring the old one.
```text

Lambda IAM roles for each integration must have
`secretsmanager:GetSecretValue` on their specific
secret ARN only — not `secretsmanager:*`.

```json
{
  "Effect": "Allow",
  "Action": "secretsmanager:GetSecretValue",
  "Resource": "arn:aws:secretsmanager:af-south-1:ACCOUNT:secret:avis/integrations/airline-loyalty/*"
}
```text

**Definition of Done:**

- [ ] All partner credentials in Secrets Manager
- [ ] IAM role scoped to specific secret ARN
- [ ] 90-day rotation configured per partner
- [ ] No credentials in Lambda environment variables
- [ ] Pre-commit hook blocks credential commits

---

## SR-INT-003 — Field Filtering per Partner

**Severity:** CRITICAL
**STRIDE ref:** T-009 (PII oversharing to partners)
**Compliance:** POPIA s19, GDPR Art.5(1)(c)
**Added:** Integration layer threat modelling

Each partner receives only the fields documented
in their Data Processing Agreement (DPA).
API Gateway response transformation strips
all other fields before the response leaves Avis.

```text
PARTNER: Airline Loyalty Programme
─────────────────────────────────────────────
PERMITTED FIELDS:
  booking_reference    (not booking_id)
  customer_first_name  (not full name)
  flight_number        (from booking)
  rental_start_date
  rental_end_date
  loyalty_points_earned

EXPLICITLY DENIED:
  sa_id_number         ← NEVER to any partner
  passport_number      ← NEVER to any partner
  home_address         ← NEVER to any partner
  payment_details      ← NEVER to any partner
  driver_licence       ← NEVER to any partner
  gps_history          ← NEVER to any partner

IMPLEMENTATION:
API Gateway response transformation template
strips all fields not in PERMITTED list before
response is sent. Lambda does not filter —
API Gateway is the enforcement point.
```text

```json
// API Gateway mapping template — airline partner
#set($inputRoot = $input.path('$'))
{
  "booking_reference": "$inputRoot.booking_reference",
  "customer_first_name": "$inputRoot.customer.first_name",
  "rental_start_date": "$inputRoot.rental_start_date",
  "rental_end_date": "$inputRoot.rental_end_date",
  "loyalty_points_earned": $inputRoot.loyalty_points
}
```text

**Definition of Done:**

- [ ] Field list documented per partner in DPA register
- [ ] API Gateway mapping template implemented per partner
- [ ] Integration test: response contains only permitted fields
- [ ] Penetration test: cannot retrieve sa_id via partner endpoint
- [ ] Macie scan: no unexpected PII in partner S3 staging buckets

---

## SR-INT-004 — Integration Audit Logging

**Severity:** HIGH
**STRIDE ref:** T-008 (Repudiation), T-009
**Compliance:** POPIA s19, ISO 27001 A.12.4

Every outbound partner API call must produce
a structured audit log entry. If a breach occurs,
the Security team must be able to determine exactly
what data was sent to each partner and when.

```json
{
  "timestamp": "2025-01-15T14:23:07Z",
  "event_type": "PARTNER_API_CALL",
  "partner_name": "airline-loyalty",
  "direction": "OUTBOUND",
  "endpoint": "POST /loyalty/points/credit",
  "booking_reference": "BK-2025-001234",
  "fields_sent": [
    "booking_reference",
    "customer_first_name",
    "loyalty_points_earned"
  ],
  "http_status": 200,
  "response_time_ms": 342,
  "tls_version": "TLSv1.3",
  "outcome": "SUCCESS"
}
```text

Note: `fields_sent` logs field NAMES only.
Field VALUES must never appear in audit logs.
This protects PII while maintaining audit trail.

**Definition of Done:**

- [ ] All integration Lambdas emit structured audit log
- [ ] fields_sent contains names not values
- [ ] CloudWatch log group per integration partner
- [ ] CloudTrail picks up integration log group
- [ ] Audit log queryable: "what did we send to airline partner on date X"

---

## SR-INT-005 — Inbound Payload Validation

**Severity:** HIGH
**STRIDE ref:** T-003 (Tampering — inbound webhooks)
**Compliance:** ISO 27001 A.13.1

Inbound webhook payloads from partners (e.g. Jumio
verification results, airline booking confirmations)
must be validated before processing.

```python
import hmac
import hashlib

def validate_webhook(payload: bytes, signature: str,
                     secret: str) -> bool:
    """
    Validate HMAC-SHA256 signature on inbound webhook.
    Prevents spoofed webhook payloads from triggering
    booking confirmation or verification status changes.
    """
    expected = hmac.new(
        secret.encode(),
        payload,
        hashlib.sha256
    ).hexdigest()

    # Constant-time comparison prevents timing attacks
    return hmac.compare_digest(
        f"sha256={expected}",
        signature
    )

# USAGE in Lambda handler
def lambda_handler(event, context):
    payload = event['body'].encode()
    signature = event['headers']['X-Webhook-Signature']
    secret = get_secret('avis/integrations/jumio/webhook-secret')

    if not validate_webhook(payload, signature, secret):
        logger.warning("Invalid webhook signature rejected")
        return {'statusCode': 401}

    # Process verified payload only
    process_verification_result(json.loads(payload))
```text

**Definition of Done:**

- [ ] HMAC validation on all inbound partner webhooks
- [ ] Invalid signature returns 401 and logs warning
- [ ] Webhook secret stored in Secrets Manager
- [ ] Timing-safe comparison used (hmac.compare_digest)
- [ ] Integration test: tampered payload rejected

---

## SR-INT-006 — Partner Onboarding Checklist

Before any new integration goes live, the following
must be completed and signed off by the Security Architect:

| Item | Owner | Status |
|------|-------|--------|
| Data Processing Agreement (DPA) signed | Legal | |
| Field list documented and approved | Security Architect | |
| Dedicated credentials created in Secrets Manager | Integration Architect | |
| TLS 1.3 confirmed on partner endpoint | Integration Engineer | |
| API Gateway response transformation tested | Integration Engineer | |
| Audit logging verified in CloudWatch | Integration Engineer | |
| HMAC webhook validation implemented | Integration Engineer | |
| Penetration test: PII cannot be extracted | Security Architect | |
| Macie scan: no PII in partner staging bucket | Security Architect | |
| **Security Architect sign-off** | Security Architect | |

---

## Partner Registry

| Partner | Purpose | Fields Permitted | DPA Status | Credentials Location |
|---------|---------|-----------------|------------|---------------------|
| Airline Loyalty Programme | Loyalty points crediting | booking_reference, first_name, points | Signed | `avis/integrations/airline-loyalty/` |
| Home Affairs (DHA) | SA ID verification | sa_id (outbound), valid/invalid (inbound) | Government SLA | `avis/integrations/home-affairs-dha/` |
| Jumio | Foreign passport MRZ verification | passport_mrz_data | Signed (GDPR compliant) | `avis/integrations/jumio/` |
| AWS Rekognition (eu-west-1) | Face comparison | passport_photo (biometric) | AWS DPA | IAM role — no API key |
| eNaTIS | SA licence validation | licence_number (outbound), valid/invalid (inbound) | Government SLA | `avis/integrations/enatis/` |

# STRIDE Threat Register
## Avis Fleet & Mobility Platform

> **Methodology:** STRIDE (Spoofing, Tampering, Repudiation,
> Information Disclosure, Denial of Service, Elevation of Privilege)
>
> **Risk Rating:** Likelihood (L/M/H) × Impact (L/M/H/Critical)
>
> **Review Cycle:** Quarterly, or after any significant architecture change

---

## How to Read This Register

Each row is a specific, realistic threat scenario — not a vague category.
The "Threat Description" column describes the attacker's exact action.
The "Mitigations" column describes the controls that break the attack chain.

---

## Threat Register

| # | Component | STRIDE | Threat Description | Likelihood | Impact | Risk | Mitigations | AWS Controls |
|---|-----------|--------|--------------------|------------|--------|------|-------------|--------------|
| T-001 | Customer Auth (Cognito) | **Spoofing** | Attacker replays a stolen JWT token from a compromised mobile device to impersonate a legitimate customer and access their booking history and saved payment methods | High | Critical | **CRITICAL** | Short JWT TTL (15 min); refresh-token rotation on every use; device fingerprinting embedded in token claims; step-up MFA required for payment and PII changes | Cognito Advanced Security Mode (AFSM); Lambda authoriser validates all claims including device fingerprint; CloudFront + WAF rate limiting on auth endpoints |
| T-002 | Customer Auth (Cognito) | **Elevation of Privilege** | Malicious customer manipulates their Cognito group claims (e.g. by forging a JWT or exploiting a misconfigured client) to access admin booking-management endpoints reserved for Avis staff | Medium | Critical | **CRITICAL** | JWT claim validation in Lambda authoriser rejects tokens with unexpected group claims; Cognito group-based role mapping with explicit deny on admin scopes; API Gateway resource policies block non-staff endpoints | Lambda authoriser with group claim validation; Cognito user pool groups; API Gateway resource policy; IAM permission boundaries on Lambda execution roles |
| T-003 | Booking API (API Gateway) | **Tampering** | Attacker intercepts a booking request in transit using a MITM proxy and modifies the vehicle class or price field, obtaining a premium vehicle at economy pricing | Medium | High | **HIGH** | TLS 1.3 enforced end-to-end (no TLS 1.0/1.1 permitted); API Gateway request validation schemas reject unexpected field values; signed API requests (SigV4) for internal service-to-service calls; input sanitisation in Lambda handler | API Gateway request validators with JSON schema; ACM certificates; WAF managed rules for injection; CloudFront HTTPS-only policy |
| T-004 | Booking API (API Gateway) | **Denial of Service** | Automated bot floods the booking search API with 50,000 requests per minute, exhausting Lambda concurrency and triggering RDS connection pool exhaustion, making the platform unavailable during peak travel season | High | High | **HIGH** | WAF rate-based rules (1,000 req/5 min per IP); API Gateway throttling and usage plans per client; Lambda reserved concurrency per function; RDS Proxy absorbs connection spikes | AWS WAF Bot Control managed rule group; API Gateway throttle limits; AWS Shield Standard; RDS Proxy; CloudWatch Lambda concurrency alarms to SOC |
| T-005 | PII Data Store (Aurora RDS) | **Information Disclosure** | Attacker exploits an unsanitised booking search parameter with SQL injection (e.g. `' OR 1=1--`) to extract the full customer PII table including SA ID numbers, home addresses, and driver's licence numbers | Medium | Critical | **CRITICAL** | Parameterised queries enforced via ORM (no dynamic SQL); WAF SQL injection managed rule set; DB user least-privilege (SELECT only on required columns, no access to admin tables); PII tokenisation at application layer | WAF SQL injection managed rules; Aurora: IAM authentication (no static DB passwords); Secrets Manager for DB credential rotation every 30 days; Macie for PII detection in S3 backups |
| T-006 | PII Data Store (Aurora RDS) | **Tampering** | Compromised ECS task role (via stolen container environment variable) is used to UPDATE booking records — falsifying accident history for a vehicle to avoid insurance claims or commit fraud | Low | Critical | **HIGH** | DB role separation: application role has INSERT/SELECT only, no UPDATE on closed bookings; Row-level version tracking in database; Aurora audit logs shipped to immutable S3 WORM bucket | Aurora audit log to CloudWatch Logs; IAM role conditions restricting access to source VPC; S3 Object Lock COMPLIANCE for audit logs; AWS Config rule checking RDS for public access |
| T-007 | Fleet GPS (IoT Core) | **Spoofing** | Attacker sends fabricated GPS coordinates for a stolen vehicle to IoT Core using a cloned device certificate, hiding the vehicle's real location and manipulating mileage-based billing for the customer | Medium | High | **HIGH** | Unique X.509 certificate per vehicle VIN (no shared certificates); certificate revocation via IoT Core device registry when vehicle is reported stolen; anomaly detection on impossible travel speed (>300km/h between readings) | IoT Core per-device X.509 certificates; IoT Device Defender audit and detect rules; Kinesis Data Analytics anomaly detection on GPS streams; GuardDuty threat intelligence for known malicious IPs |
| T-008 | Fleet GPS (IoT Core) | **Repudiation** | A fleet operations staff member modifies a vehicle's IoT device shadow state (e.g. resetting a damage flag) and later denies doing so — there is no tamper-evident audit trail for shadow modifications | Low | Medium | **MEDIUM** | IoT Core device shadow update events logged to CloudTrail data plane; all shadow changes include operator identity from IAM; immutable event stream in Kinesis + S3 WORM with Object Lock | CloudTrail: IoT data-plane logging enabled; S3 Object Lock COMPLIANCE mode for IoT events; Kinesis Firehose to S3 with KMS encryption; CloudWatch Logs Insights for shadow change queries |
| T-009 | Integration Layer (Partner APIs) | **Information Disclosure** | The airline loyalty partner API integration sends full customer PII (name, SA ID, home address) to the partner in the booking confirmation payload, violating the data minimisation principle and exposing unnecessary personal data to a third party | High | High | **HIGH** | API response transformation layer strips all fields not required by specific partner (field-level access control per partner scope); data masking for sensitive fields; partner-specific JWT scopes limiting data access; Data Processing Agreement (DPA) with each partner | API Gateway response transformation templates; Lambda authoriser with partner-scoped claim validation; AWS PrivateLink for trusted partners (no public internet); Macie scanning of S3 staging buckets used for partner data exchange |
| T-010 | Admin Console (IAM Identity Center) | **Elevation of Privilege** | A SOC analyst uses a shared admin account (with static access keys stored in a shared password manager) to directly query the production Aurora database, bypassing all audit controls and accessing full PII dataset | Medium | Critical | **CRITICAL** | IAM Identity Center enforces SAML federation — no long-lived access keys for human users; SCPs deny CreateAccessKey for human IAM users; SSM Session Manager for all DB access (no direct SSH/RDP); just-in-time privileged access with dual approval via ITSM ticket | IAM Identity Center with mandatory MFA; SCP: DenyCreateAccessKeyForHumanUsers; SSM Session Manager (all sessions logged to CloudTrail and S3); AWS Config: root-account-mfa-enabled rule |
| T-011 | CloudTrail / Audit Logs | **Tampering** | Compromised administrator account (obtained via phishing) attempts to delete CloudTrail logs or disable the trail to cover their tracks after exfiltrating customer PII — leaving no forensic evidence for incident response | Low | Critical | **HIGH** | CloudTrail log file validation enabled (SHA-256 digest files); S3 audit bucket in a separate AWS account with Object Lock COMPLIANCE (7 years — even root cannot delete); GuardDuty detects CloudTrailLoggingDisabled finding within 15 minutes | CloudTrail log file integrity validation; S3 Object Lock COMPLIANCE 7-year retention; Separate audit account in AWS Organizations; GuardDuty finding type: Stealth:IAMUser/CloudTrailLoggingDisabled |
| T-012 | Mobile App (Client-side) | **Tampering** | Attacker reverse-engineers the Avis mobile app, extracts hardcoded API endpoint URLs and any embedded credentials, and uses them to make direct API calls bypassing the app's input validation and rate limiting logic | Medium | High | **HIGH** | No credentials or secrets in mobile app binary; API Gateway requires valid Cognito JWT — raw endpoint calls without auth token are rejected; Certificate pinning in mobile app to prevent proxy-based MITM; App binary obfuscation and integrity checks | API Gateway: all endpoints require Lambda authoriser; Cognito: PKCE flow ensures no client secrets in mobile app; AWS WAF user-agent anomaly detection; CloudFront signed URLs for any static content requiring auth |
| T-013 | Session Management (DynamoDB) | **Information Disclosure** | An attacker who gains read access to the DynamoDB session table (e.g. via misconfigured IAM role) extracts active session tokens for multiple customers, enabling account takeover without needing passwords | Low | Critical | **HIGH** | Session tokens are hashed before storage (never stored as plaintext); DynamoDB table encrypted with dedicated KMS CMK; IAM role for session service has GetItem only on own user's partition key (attribute-based access control); Sessions expire after 15 minutes with TTL | DynamoDB: encryption at rest with KMS CMK avis/sessions; IAM condition: `dynamodb:LeadingKeys` restricts role to own user's records only; DynamoDB TTL auto-deletes expired sessions; GuardDuty: detects anomalous DynamoDB scan operations |
| T-014 | AI Pricing Engine (Lambda + SageMaker) | **Tampering** | Attacker discovers the AI pricing model's training data pipeline reads from an S3 bucket with overly permissive IAM policy, and injects poisoned training records (e.g. fake historical bookings with manipulated prices) to systematically bias the model toward under-pricing premium vehicles | Low | High | **MEDIUM** | Training data pipeline validates checksums of input data against a signed manifest stored separately; SageMaker training job IAM role has read-only access to a specific versioned S3 prefix only; Data lineage tracking logs all training data inputs; Anomaly detection on model output price distribution before promotion to production | S3 Object Lock on training data bucket (prevents modification of historical records); SageMaker: separate IAM role per pipeline stage; CloudTrail: logs all S3 GetObject on training bucket; SageMaker Model Monitor detects output distribution drift |

---

## Risk Summary

| Risk Level | Count | Threats |
|------------|-------|---------|
| 🔴 CRITICAL | 4 | T-001, T-002, T-005, T-010 |
| 🟠 HIGH | 8 | T-003, T-004, T-006, T-007, T-009, T-011, T-012, T-013 |
| 🟡 MEDIUM | 2 | T-008, T-014 |
| 🟢 LOW | 0 | — |

---

## STRIDE Coverage Matrix

> Confirms all 6 STRIDE categories are covered across all components.

| Component | S | T | R | I | D | E |
|-----------|---|---|---|---|---|---|
| Customer Auth (Cognito) | T-001 | — | — | — | — | T-002 |
| Booking API (API Gateway) | — | T-003 | — | — | T-004 | — |
| PII Data Store (Aurora) | — | T-006 | — | T-005 | — | — |
| Fleet GPS (IoT Core) | T-007 | — | T-008 | — | — | — |
| Integration Layer | — | — | — | T-009 | — | — |
| Admin Console (IAM) | — | — | — | — | — | T-010 |
| Audit Logs (CloudTrail) | — | T-011 | — | — | — | — |
| Mobile App | — | T-012 | — | — | — | — |
| Session Management | — | — | — | T-013 | — | — |
| AI Pricing Engine | — | T-014 | — | — | — | — |

✅ All 6 STRIDE categories covered
✅ All 7 core components covered
⚠️ Gaps to address in next review: Repudiation on Booking API; DoS on IoT Core
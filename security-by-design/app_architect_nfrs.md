# Application Security NFRs
## Handoff to: Application Architect & Development Teams
## From: Security Architect
## Version: 1.0 | Status: Approved

---

## Purpose

This document translates the security architecture controls into
non-functional requirements (NFRs) for the application development team.
Each NFR maps to a specific threat from the STRIDE register and a
compliance obligation.

**How to use this:** Each NFR should become an acceptance criterion on
the relevant user story. NFRs marked CRITICAL block release if not met.

---

## NFR Reference Table

| ID | Category | Requirement | Severity | STRIDE Ref | Compliance |
|----|----------|-------------|----------|-----------|------------|
| SR-APP-001 | Authentication | All API endpoints except `/health` and `/api/docs` must require a valid Cognito JWT in the `Authorization: Bearer` header. The Lambda authoriser must validate: RS256 signature, token expiry, audience (`aud` claim = Cognito client ID), issuer (`iss` claim = Cognito pool URL), and device fingerprint claim. | CRITICAL | T-001 (Spoofing) | POPIA s19, ISO A.5.15 |
| SR-APP-002 | Authentication | Payment and PII-modification endpoints (`/payments/*`, `/profile/update`) must require a `step_up_mfa` JWT claim with a timestamp within the last 10 minutes. If the claim is absent or expired, the API must return HTTP 403 and redirect the client to the MFA step-up flow. | CRITICAL | T-002 (EoP) | PCI-DSS 8.3 |
| SR-APP-003 | Input Validation | All user-supplied inputs must be validated server-side against a strict JSON schema before any database query or downstream call. Validation must reject: unexpected fields, values exceeding max length, type mismatches, and any SQL metacharacters in string fields. No dynamic SQL construction — use parameterised queries or ORM exclusively. | CRITICAL | T-005 (Info Disclosure) | OWASP API8 |
| SR-APP-004 | Error Handling | API error responses must not expose: stack traces, internal server paths, database table names, column names, AWS account IDs, or Lambda function names. Use generic error codes (e.g. `ERR_4001`) mapped to internal logs only. Log the full error internally with correlation ID. | HIGH | T-003 (Tampering) | OWASP API3 |
| SR-APP-005 | Secrets Management | No database credentials, API keys, private keys, or tokens may appear in: source code, environment variables in code, Docker image layers, or CI/CD logs. All secrets must be retrieved from AWS Secrets Manager at runtime using the Lambda/ECS task IAM role. | CRITICAL | T-010 (EoP) | ISO A.5.17 |
| SR-APP-006 | Logging | All the following events must emit a structured JSON log entry to CloudWatch Logs with fields: `timestamp`, `userId`, `action`, `resourceId`, `sourceIP`, `sessionId`, `result` (success/failure): booking create/modify/cancel, payment initiation, PII field access or update, login success/failure, MFA challenge. | HIGH | T-008 (Repudiation) | POPIA s19, ISO A.8.16 |
| SR-APP-007 | Dependency Management | All Lambda and container dependencies must be scanned with Snyk or AWS Inspector in the CI pipeline before deployment. No CRITICAL or HIGH CVEs permitted in production builds. Dependabot or equivalent must be configured for weekly automated dependency update PRs. | HIGH | General | ISO A.8.25 |
| SR-APP-008 | Session Management | Session tokens must never be stored in localStorage or sessionStorage (XSS vulnerable). Use httpOnly, Secure, SameSite=Strict cookies for web sessions. Mobile app uses Cognito secure token storage (Keychain on iOS, Keystore on Android). Session invalidation must occur on logout, password change, and MFA change. | HIGH | T-013 (Info Disclosure) | OWASP API2 |

---

## Acceptance Criteria Template

For each NFR above, the following acceptance criteria apply at code review:
```
GIVEN: [the scenario the requirement addresses]
WHEN:  [the action that triggers the control]
THEN:  [the expected secure behaviour]

Example for SR-APP-001:
GIVEN: An unauthenticated request to /api/bookings
WHEN:  The request has no Authorization header
THEN:  API Gateway returns HTTP 401 before the request reaches the Lambda function
```

---

## Security Review Checklist (for PR reviewers)

Before approving any PR touching authentication, payment, or PII flows:

- [ ] SR-APP-001: Does this endpoint have Lambda authoriser protection?
- [ ] SR-APP-003: Are all inputs validated with a schema?
- [ ] SR-APP-004: Do error responses contain no internal details?
- [ ] SR-APP-005: Are there any hardcoded credentials? (run `detect-secrets scan`)
- [ ] SR-APP-006: Are audit events logged for this action?

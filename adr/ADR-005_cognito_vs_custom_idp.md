# ADR-005: Amazon Cognito for Customer Authentication

| Field | Value |
|-------|-------|
| Status | Accepted |
| Date | 2025-Q1 |
| Deciders | Security Architect, App Architect, CISO |
| SABSA Layer | Physical (identity control implementation) |

---

## Context

Customer authentication for the mobile app and web portal requires
an identity provider (IdP). Approximately 500,000 customers (MAUs)
require secure registration, login, MFA, and account recovery. The
solution must satisfy POPIA data residency requirements (data stored
in South Africa), support PKCE for mobile clients, and provide
anomaly detection for compromised credential attacks.

## Decision

Adopt Amazon Cognito User Pools for customer authentication with
Advanced Security Mode (AFSM) enforced. Cognito handles password
policies, MFA (TOTP + SMS), PKCE flows for mobile, and POPIA-compliant
account deletion. All data stored in af-south-1 (Cape Town) for POPIA
data residency.

## Rationale

- **POPIA data residency:** af-south-1 keeps all customer auth data
  within South Africa — satisfying POPIA's cross-border transfer
  restrictions without additional mechanisms
- **Security by default:** Cognito AFSM provides ML-based anomaly
  detection (impossible travel, credential stuffing, new device login)
  out of the box — equivalent capability would require significant
  custom engineering
- **OWASP compliance:** JWT implementation, PKCE flow, token rotation,
  and refresh token revocation are all handled correctly by Cognito —
  JWT vulnerabilities (OWASP API Security A2) are the most common auth
  failure; using a managed service eliminates implementation risk
- **ISO 27001 A.9.4.2:** Application access control satisfied through
  Cognito's user pool groups and scope-based access

## Consequences

**Positive:**
- POPIA-compliant data residency in af-south-1 by default
- Advanced Security Mode detects and blocks high-risk sign-ins automatically
- No JWT implementation bugs — Cognito is AWS-audited and certified
- 50,000 MAU free tier covers development and initial production

**Negative / Trade-offs:**
- Vendor lock-in to AWS Cognito APIs — mitigated by abstracting auth
  behind an AuthService interface in the application layer
- Cognito has some UX limitations for complex identity flows (e.g.
  custom authentication challenges require Lambda triggers)
- Cognito does not support all enterprise identity federation use cases
  natively — acceptable for this customer-facing scope

## Alternatives Considered

| Option | Why Rejected |
|--------|-------------|
| Custom JWT service | High implementation risk; JWT vulnerabilities consistently in OWASP Top-10; requires dedicated security engineering to maintain and audit |
| Auth0 | Excellent product; adds ~$0.023/MAU above 7,000 MAUs; introduces third-party data processor requiring POPIA DPIA; data residency in AWS region not guaranteed |
| Keycloak (self-hosted) | Open source, flexible; requires dedicated infrastructure, patching, and 24/7 availability management — operational overhead not justified when Cognito provides equivalent capability |

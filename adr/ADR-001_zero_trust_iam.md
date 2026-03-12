# ADR-001: AWS IAM Identity Center for Zero-Trust Human Identity

| Field | Value |
|-------|-------|
| Status | Accepted |
| Date | 2025-Q1 |
| Deciders | Security Architect, CTO, CISO |
| SABSA Layer | Physical (implements Conceptual zero-trust principle) |

---

## Context

The organisation had ~200 IT staff and contractors accessing AWS accounts
using individual IAM users with long-lived access keys stored in a shared
spreadsheet. Multiple incidents involved shared credentials and no MFA
enforcement. The CISO's zero-trust mandate requires: federated identity,
MFA on every login, short-lived credentials, and no long-lived access keys
for human users. A centralised identity solution is needed immediately.

## Decision

Adopt AWS IAM Identity Center (formerly AWS SSO) as the sole mechanism
for human access to AWS accounts, federated with the corporate Azure AD
via SAML 2.0. All permission sets enforce MFA and maximum 4-hour session
durations. Long-lived IAM access keys for human users are prohibited via
Service Control Policy (SCP).

## Rationale

IAM Identity Center directly implements NIST SP 800-207 Zero-Trust Pillar 1
(Identity Verification):

- **Federation with Azure AD** means HR's join/leave/move process automatically
  propagates to AWS access — no orphaned accounts
- **SAML assertion model** means AWS never receives the actual credential,
  only a signed assertion from Azure AD
- **Short-lived sessions (4h)** limit blast radius of token theft
- **TOGAF principle** of "single point of identity control" is satisfied
- **ISO 27001 A.9.2.1** (user registration and deregistration) is met through
  the Azure AD integration

## Consequences

**Positive:**

- Eliminates long-lived AWS access keys for human users entirely
- Every login produces an auditable event in CloudTrail (sso.amazonaws.com)
- Permission sets can be updated centrally and apply to all accounts instantly
- Aligns with CIS AWS Foundations Benchmark v1.4 control 1.1

**Negative / Trade-offs:**

- Dependency on Azure AD availability (if Azure AD is down, AWS console
  access is unavailable for human users)
- Initial setup requires console steps that cannot be fully Terraformed
  on first run (chicken-and-egg: need access to create the SSO config)
- Mitigation: break-glass IAM user with hardware MFA stored in sealed
  envelope in physical safe — access logged and reviewed

## Alternatives Considered

| Option | Why Rejected |
|--------|-------------|
| Continue with IAM users + MFA | Does not eliminate static long-lived credentials; requires manual lifecycle management; cannot enforce least-privilege at scale; fails zero-trust mandate |
| Okta as external IdP | Excellent product but adds cost (~$4/user/month) and a third-party data processor requiring POPIA DPIA; Azure AD is already licensed and provides equivalent SAML federation |
| Custom LDAP + Vault | Significant engineering effort; introduces another system to maintain; re-invents capabilities already in IAM Identity Center |

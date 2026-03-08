# Integration Security Standards
## Handoff to: Integration Architect
## From: Security Architect
## Version: 1.0 | Status: Approved

---

## Purpose

This guide defines the security standards for all third-party
integrations (airline loyalty programmes, insurance brokers,
payment gateways, fleet telematics providers).

Every integration must be approved through the Integration Security
Review process before connecting to production systems.

---

## Integration Security Requirements

| ID | Requirement | Severity | Notes |
|----|-------------|----------|-------|
| SR-INT-001 | All integration endpoints must use TLS 1.2 minimum (TLS 1.3 preferred). No unencrypted HTTP connections to any partner API permitted in any environment. | CRITICAL | Enforce via AWS Certificate Manager + API Gateway TLS policy |
| SR-INT-002 | Each partner integration must have a dedicated IAM role or API key with the minimum required permissions. Shared credentials across partners are prohibited. | CRITICAL | Separate Secrets Manager secret per partner; rotated every 90 days |
| SR-INT-003 | Data sent to partner APIs must be filtered to include only fields explicitly listed in the signed Data Processing Agreement (DPA). The integration layer must enforce field-level filtering — never pass raw booking objects. | CRITICAL | Lambda response transformation; POPIA s21 data processor obligation |
| SR-INT-004 | All partner API calls must be logged with: partner name, endpoint called, fields sent (names only, not values for PII), response status, timestamp, and correlation ID. Logs retained for 7 years. | HIGH | POPIA audit obligation; CloudTrail + CloudWatch Logs |
| SR-INT-005 | Inbound webhook payloads from partners must be validated: HMAC signature verification before processing, payload schema validation, and idempotency checks to prevent replay attacks. | HIGH | T-003 (Tampering) mitigation for inbound flows |
| SR-INT-006 | Partner API credentials must be stored in Secrets Manager (not environment variables or config files). The integration Lambda's IAM role must have GetSecretValue permission for only its own secret. | HIGH | ISO A.5.17 |

---

## Pre-Integration Security Checklist

Before any new integration goes live, the Integration Architect must
confirm all of the following with the Security Architect:

- [ ] DPA signed and reviewed by Legal — data fields listed match SR-INT-003
- [ ] Partner TLS certificate validated — no self-signed certs in production
- [ ] Dedicated IAM role/credentials created (SR-INT-002)
- [ ] Credentials stored in Secrets Manager with rotation configured
- [ ] Field-level filtering implemented and tested (SR-INT-003)
- [ ] Logging confirmed in CloudWatch Logs (SR-INT-004)
- [ ] HMAC/signature validation implemented for inbound webhooks (SR-INT-005)
- [ ] Penetration test or security review completed for new integration

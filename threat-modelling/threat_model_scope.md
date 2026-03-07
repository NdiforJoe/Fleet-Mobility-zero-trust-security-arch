# Threat Model Scope
## Avis Fleet & Mobility Platform

### Version
| Field | Value |
|-------|-------|
| Version | 1.0 |
| Date | 2025-Q1 |
| Methodology | STRIDE |
| Author | Security Architect |
| Status | Draft |

---

### What Is In Scope

| Component | Description | Trust Level |
|-----------|-------------|-------------|
| Customer Auth (Cognito) | Mobile + web customer login | External/Untrusted |
| Booking API (API Gateway) | REST API for booking operations | External/Untrusted |
| PII Data Store (Aurora RDS) | Customer personal information | Internal/Trusted |
| Fleet GPS (IoT Core) | Vehicle telematics and tracking | Device-Certified |
| Integration Layer | Third-party airline/insurance APIs | External Partner |
| Admin Console (IAM) | Internal IT and SOC access | Internal/Privileged |
| Audit Logs (CloudTrail) | Security audit trail | Internal/Privileged |

### What Is Out of Scope
- Payment card processing (handled by tokenisation service — PCI-DSS boundary)
- Physical vehicle security
- Third-party partner internal systems

### Assumptions
- AWS infrastructure is correctly patched (shared responsibility model)
- TLS certificates are valid and properly managed
- Developers follow secure coding guidelines (see security-by-design/)

### Trust Boundaries
1. Internet → AWS Edge (CloudFront + WAF)
2. API Gateway → Application VPC
3. Application tier → Data tier
4. IoT devices → IoT Core
5. Integration layer → Partner APIs

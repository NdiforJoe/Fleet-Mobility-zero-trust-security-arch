# SABSA Security Architecture Matrix
## Fleet & Mobility Order Platform — Avis South Africa

> **Framework:** Sherwood Applied Business Security Architecture (SABSA)
> **Purpose:** Structure the security architecture across all six layers,
> from Board-level business risk down to operational procedures.

---

## How to Read This Matrix

Each row is a *layer* of abstraction. Each column answers a different question
about security at that layer. The key principle: **every cell in a lower layer
must implement or support the cell directly above it.**

Read it top-down to understand the architecture.
Read it bottom-up to trace any control back to a business reason.

---

## The Matrix

| Layer | What (Assets / Goals) | Why (Risks / Motivation) | How (Controls / Processes) | Who (People / Roles) | Where / When (Architecture Principles) |
|-------|----------------------|--------------------------|----------------------------|---------------------|----------------------------------------|
| **Contextual** *(Business View)* | Customer PII (SA ID, address, payment refs); Fleet GPS telemetry; Booking platform availability; Brand trust and regulatory licence to operate | Customer data breach → POPIA fine up to R10M + reputational damage; Platform downtime → revenue loss >R500K/day; GPS data misuse → customer safety risk; Non-compliance → loss of operating licence | Business risk appetite documented by Board; POPIA compliance programme; ISO 27001 certification target; Executive security steering committee | CISO, CFO, Legal/Compliance, Board Risk Committee, CTO | Risk appetite: Low for data breach; Medium for availability; Regulatory deadline: POPIA compliance within 12 months |
| **Conceptual** *(Architect View)* | Zero-trust security model; Identity-centric perimeter; Data-centric protection; Assume-breach posture | Privilege escalation by insider; Lateral movement after external breach; Data exfiltration via API; Credential theft targeting fleet operators | Zero-trust principles (NIST SP 800-207): verify explicitly, use least privilege, assume breach; Defence-in-depth; Security-by-design embedded from architecture stage | Security Architect, Enterprise Architect, CTO | Principle: Never trust, always verify — regardless of network location. Every identity verified. Every request authorised. Every data asset encrypted. |
| **Logical** *(Designer View)* | Hub-spoke VPC network topology; Identity federation with MFA; TLS 1.3 everywhere; Tokenised PII in data layer; Centralised SIEM detection | STRIDE threat model output (see threat-modelling/): 11 identified threats across auth, data, IoT, and integration layers | IAM policies with least privilege; Encryption at rest and in transit; API authentication flows; Network segmentation rules; Audit log requirements; Data classification tiers | Solution Architects, App Architect, Data Architect, Integration Architect | Architecture patterns: micro-segmentation, secrets management, data tokenisation, zero-standing privilege |
| **Physical** *(Builder View)* | AWS Transit Gateway hub-spoke; Cognito user pools; KMS Customer Managed Keys per data class; GuardDuty + Security Hub; WAF on API Gateway | Attack surface per AWS service; Network path analysis; Cryptographic strength validation per data tier | VPC CIDR allocations with spoke isolation; IAM role boundaries and SCPs; KMS key policies per classification; S3 bucket policies with Object Lock; CloudTrail configuration | Cloud Engineers, DevOps Engineers, Network Engineers | AWS Well-Architected Security Pillar; CIS AWS Foundations Benchmark v1.4; af-south-1 region for POPIA data residency |
| **Component** *(Tradesman View)* | Terraform modules: vpc_hub_spoke, iam_identity_center, kms_key_set, guardduty_org, security_hub, waf_api_gateway, cognito_pool; Lambda authoriser code; SSM Parameter Store secrets | Lambda cold-start injection; S3 misconfiguration; KMS key rotation lapse; Container image CVEs | Terraform state in encrypted S3 + DynamoDB lock; Module version pins; tfsec/checkov IaC scanning gates in CI pipeline; Snyk for Lambda dependencies | DevSecOps Engineers, Developers | Checkov/tfsec IaC scanning; Snyk dependency scanning; OWASP Top-10 per API endpoint; Pre-commit hooks for secret detection |
| **Operational** *(Service Mgr View)* | SOC runbooks for GuardDuty findings; Incident response playbook IR-001; Change management via CAB; Quarterly penetration testing; Monthly ISMS review | Runtime threats: credential stuffing on booking API; DDoS; ransomware on database; insider exfiltration via fleet management system | CloudWatch alarms; Security Hub findings SLA (Critical <4h, High <24h); Audit evidence collection for ISO 27001 Annex A; POPIA data-subject request SLA 72h | SOC Analysts, CISO, IT Operations, Compliance Manager | ISO 27001 Annex A controls; NIST CSF Respond/Recover functions; POPIA Chapter 3 obligations |

---

## SABSA Security Attributes (cross-cutting)

These attributes apply across ALL layers. Every control in the matrix above
should map to at least one of these:

| Attribute | Definition | Avis Example |
|-----------|-----------|--------------|
| **Confidentiality** | Information only accessible to authorised parties | KMS encryption of PII; VPC isolation of Aurora |
| **Integrity** | Information is accurate and unmodified | CloudTrail log file validation; RDS audit logs |
| **Availability** | Systems accessible when needed | Multi-AZ Aurora; RDS Proxy connection pooling |
| **Authenticity** | Identity of parties can be verified | Cognito JWT + Lambda authoriser on every request |
| **Non-repudiation** | Actions cannot be denied | CloudTrail + S3 WORM; IoT device X.509 certs |
| **Privacy** | Personal data handled per regulation | POPIA consent in Cognito; data minimisation in APIs |
| **Authorisation** | Access limited to what is needed | IAM least-privilege; Cognito scopes per endpoint |

---

## Traceability Example

> **How to use this in an interview:**
> Pick any AWS service and trace it upward through all layers.

**Example: KMS Customer Managed Key for PII**

| Layer | What this looks like |
|-------|---------------------|
| Contextual | "Customer PII must be protected against breach" |
| Conceptual | "Data-centric protection: encrypt per classification" |
| Logical | "Separate encryption keys per data classification tier" |
| Physical | "AWS KMS CMK `alias/avis/pii` in af-south-1" |
| Component | `aws_kms_key.pii` Terraform resource with key rotation enabled |
| Operational | Monthly key rotation audit; CloudTrail logs all key usage |
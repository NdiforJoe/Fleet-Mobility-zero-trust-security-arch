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
| **Contextual** *(Business View)* | Customer PII (SA ID, address, payment refs) for both SA and foreign nationals; Fleet GPS telemetry; Booking platform availability across digital and physical branch channels; Brand trust and regulatory licence to operate; Foreign customer passport and IDP data | Customer data breach → POPIA fine up to R10M + reputational damage; Platform downtime → revenue loss >R500K/day; GPS data misuse → customer safety risk; Non-compliance → loss of operating licence; Vehicle theft via identity fraud (fake SA ID or foreign passport) → direct fleet asset loss; GDPR exposure for EU customers | Business risk appetite documented by Board; POPIA compliance programme; ISO 27001 certification target; Executive security steering committee; Vehicle fraud risk appetite: Zero tolerance — all bookings require verified identity regardless of channel | CISO, CFO, Legal/Compliance, Board Risk Committee, CTO, Fleet Operations Manager | Risk appetite: Low for data breach; Zero for identity fraud; Medium for availability; Regulatory deadlines: POPIA compliance within 12 months; GDPR applies to EU national customers booking via any channel |
| **Conceptual** *(Architect View)* | Zero-trust security model applied equally to digital and physical branch channels; Identity-centric perimeter; Data-centric protection; Assume-breach posture; Multi-channel identity verification (digital AFSM + physical document verification) | Privilege escalation by insider; Lateral movement after external breach; Data exfiltration via API; Credential theft targeting fleet operators; Identity spoofing at branch counters (fake SA ID, counterfeit passport, fraudulent IDP); Idle session exposure at branch workstations | Zero-trust principles (NIST SP 800-207): verify explicitly, use least privilege, assume breach; Defence-in-depth; Security-by-design embedded from architecture stage; Same security controls applied consistently across digital and physical channels — no weaker path via branch counter | Security Architect, Enterprise Architect, CTO | Principle: Never trust, always verify — regardless of network location OR entry channel. Digital customer and walk-in customer receive identical backend security controls. Every identity verified. Every request authorised. Every data asset encrypted. |
| **Logical** *(Designer View)* | Hub-spoke VPC network topology; Identity federation with MFA for staff (IAM Identity Center) and customers (Cognito); TLS 1.3 everywhere including branch-to-AWS traffic; Tokenised PII in data layer; Centralised SIEM detection; Flexible identity document schema supporting SA ID, passport, and IDP; Real-time identity verification workflows for both SA and foreign customers | STRIDE threat model output (see threat-modelling/): 17 identified threats across auth, data, IoT, integration layers, and branch counter scenarios (T-015, T-016, T-017) | IAM policies with least privilege; Staff roles scoped per branch and function (BranchAgent, BranchManager, ForeignDeskAgent); Encryption at rest and in transit; API authentication flows; Network segmentation rules; Audit log requirements; Data classification tiers including foreign passport data; Step Functions verification workflows for SA ID (Home Affairs API) and foreign passports (Jumio/Onfido + Rekognition) | Solution Architects, App Architect, Data Architect, Integration Architect | Architecture patterns: micro-segmentation, secrets management, data tokenisation, zero-standing privilege; Branch workstations connect via AWS Direct Connect / IPSec VPN — same security path as digital channel |
| **Physical** *(Builder View)* | AWS Transit Gateway hub-spoke; Cognito user pools (customer auth); IAM Identity Center (staff auth — scoped per branch role); KMS Customer Managed Keys per data class including avis/pii for foreign document scans; GuardDuty + Security Hub; WAF on API Gateway; AWS Rekognition (face comparison for foreign customers); Step Functions (booking verification workflows); S3 (ID document photo storage, SSE-KMS encrypted) | Attack surface per AWS service; Network path analysis; Cryptographic strength validation per data tier; Branch workstation session hijack; Fake document presentation at counter; IDP validity period expiry | VPC CIDR allocations with spoke isolation; IAM role boundaries and SCPs; KMS key policies per classification; S3 bucket policies with Object Lock; CloudTrail configuration; Step Functions booking workflow: PENDING → VERIFIED → CONFIRMED state machine; Rekognition CompareFaces threshold > 90%; Jumio/Onfido API integration for passport MRZ validation | Cloud Engineers, DevOps Engineers, Network Engineers, Branch IT (workstation management) | AWS Well-Architected Security Pillar; CIS AWS Foundations Benchmark v1.4; af-south-1 region for POPIA data residency; Branch workstations: Intune-managed, auto screen lock 60 seconds, privacy screens enforced |
| **Component** *(Tradesman View)* | Terraform modules: vpc_hub_spoke, iam_identity_center, kms_key_set, guardduty_org, security_hub, waf_api_gateway, cognito_pool; Lambda authoriser code; Lambda functions: sa_id_verification (Home Affairs API), foreign_doc_verification (Jumio API), face_comparison (Rekognition), idp_validity_check (days-in-SA calculation); SSM Parameter Store secrets; Step Functions state machine definition (booking verification workflow) | Lambda cold-start injection; S3 misconfiguration exposing ID document photos; KMS key rotation lapse; Container image CVEs; Third-party verification API (Jumio/Onfido) downtime causing booking system outage; Rekognition false rejection of legitimate customers | Terraform state in encrypted S3 + DynamoDB lock; Module version pins; tfsec/checkov IaC scanning gates in CI pipeline; Snyk for Lambda dependencies; Circuit breaker pattern on Jumio/Onfido API calls (fallback to manual verification queue if API unavailable); Rekognition fallback: flag for manual supervisor review if similarity score 80–90% | DevSecOps Engineers, Developers, Branch IT | Checkov/tfsec IaC scanning; Snyk dependency scanning; OWASP Top-10 per API endpoint; Pre-commit hooks for secret detection; Jumio/Onfido SLA: 99.9% uptime; fallback procedure documented in branch SOP |
| **Operational** *(Service Mgr View)* | SOC runbooks for GuardDuty findings; Incident response playbook IR-001; Change management via CAB; Quarterly penetration testing; Monthly ISMS review; Branch staff roles: BranchAgent (create/view bookings, capture PII, process payments), BranchManager (above + void bookings, branch reports), ForeignDeskAgent (above + foreign document verification workflow, Jumio API access, IDP validation); All staff via IAM Identity Center scoped per role and branch | Runtime threats: credential stuffing on booking API; DDoS; ransomware on database; insider exfiltration via fleet management system; Branch workstation idle session exposure (T-015); SA ID fraud at counter (T-016); Foreign passport/IDP fraud at counter (T-017); Jumio/Onfido API outage during peak travel | CloudWatch alarms; Security Hub findings SLA (Critical <4h, High <24h); Audit evidence collection for ISO 27001 Annex A; POPIA data-subject request SLA 72h; Branch SOP: 60-second screen lock policy, privacy screen requirement, clear desk policy; Manual verification fallback procedure when Jumio/Onfido API is unavailable; POPIA s72 cross-border transfer controls for foreign customer data shared with international partners | SOC Analysts, CISO, IT Operations, Compliance Manager, Branch Managers, Foreign Desk Agents | ISO 27001 Annex A controls; NIST CSF Respond/Recover functions; POPIA Chapter 3 obligations; POPIA s72 cross-border transfer restrictions; GDPR Art.17 erasure and Art.20 portability obligations for EU customers; SA NRTA s23 foreign licence validity rules |

---

## SABSA Security Attributes (cross-cutting)

These attributes apply across ALL layers. Every control in the matrix above
should map to at least one of these:

| Attribute | Definition | Avis Example |
|-----------|-----------|--------------|
| **Confidentiality** | Information only accessible to authorised parties | KMS encryption of PII; VPC isolation of Aurora; S3 SSE-KMS for ID document scans (SA and foreign) |
| **Integrity** | Information is accurate and unmodified | CloudTrail log file validation; RDS audit logs; Step Functions booking state machine prevents status tampering |
| **Availability** | Systems accessible when needed | Multi-AZ Aurora; RDS Proxy connection pooling; Circuit breaker on Jumio/Onfido API prevents verification outage cascading to booking system |
| **Authenticity** | Identity of parties can be verified | Cognito JWT + Lambda authoriser on every request; Home Affairs API for SA customers; Jumio/Onfido + Rekognition for foreign customers |
| **Non-repudiation** | Actions cannot be denied | CloudTrail + S3 WORM; IoT device X.509 certs; Step Functions execution logs record agent ID, verification result, and timestamp per booking |
| **Privacy** | Personal data handled per regulation | POPIA consent in Cognito; data minimisation in APIs; POPIA s72 cross-border transfer controls; GDPR Art.17/20 for EU nationals |
| **Authorisation** | Access limited to what is needed | IAM least-privilege; Cognito scopes per endpoint; Branch staff roles scoped to branch location and function only |

---

## Customer Channel Coverage

> This table confirms the architecture applies consistent security controls
> across ALL customer touchpoints — not just the digital channel.

| Customer Type | Entry Channel | Identity Verification | Auth Method | PII Storage | STRIDE Threats |
|--------------|---------------|----------------------|-------------|-------------|----------------|
| SA Customer | Mobile App / Website | Cognito AFSM + device fingerprint | Cognito JWT (15-min TTL) | Aurora SSE-KMS (avis/pii) | T-001, T-002, T-012, T-013 |
| SA Customer | Branch Counter | Home Affairs API + ID photo (S3) | IAM Identity Center (staff JWT) | Aurora SSE-KMS (avis/pii) | T-015, T-016 |
| Foreign Customer (EU) | Branch Counter | Jumio/Onfido MRZ + Rekognition face match + credit card | IAM Identity Center (staff JWT) | Aurora SSE-KMS (avis/pii) + S3 passport scan | T-017 |
| Foreign Customer (Non-EU) | Branch Counter | Jumio/Onfido MRZ + Rekognition face match + credit card | IAM Identity Center (staff JWT) | Aurora SSE-KMS (avis/pii) + S3 passport scan | T-017 |
| Fleet Staff | Internal System | IAM Identity Center + MFA (TOTP) | Short-lived role session (4h) | Operational data only — no customer PII | T-008, T-010 |
| Third-party Partners | Integration Layer API | Partner JWT scopes + DPA | API Gateway resource policy | Filtered fields only — no raw PII | T-009 |

---

## Traceability Examples

> **How to use this in an interview:**
> Pick any AWS service or scenario and trace it upward through all layers.

### Example 1: KMS Customer Managed Key for PII

| Layer | What this looks like |
|-------|---------------------|
| Contextual | "Customer PII must be protected against breach — POPIA fine up to R10M" |
| Conceptual | "Data-centric protection: encrypt per classification tier" |
| Logical | "Separate encryption keys per data classification tier" |
| Physical | "AWS KMS CMK `alias/avis/pii` in af-south-1" |
| Component | `aws_kms_key.pii` Terraform resource with annual rotation enabled |
| Operational | Monthly key rotation audit; CloudTrail logs all decrypt operations |

---

### Example 2: Foreign Customer Identity Verification at OR Tambo

| Layer | What this looks like |
|-------|---------------------|
| Contextual | "Vehicle theft via fake foreign passport = direct fleet asset loss; zero tolerance policy" |
| Conceptual | "Same identity verification rigour for walk-in channel as digital channel — no weaker path" |
| Logical | "Step Functions verification workflow: passport MRZ + face match + credit card required before booking confirmed" |
| Physical | "Lambda → Jumio API (MRZ validation); Rekognition CompareFaces > 90%; Step Functions state machine" |
| Component | `aws_sfn_state_machine.foreign_verification` Terraform resource; Lambda `foreign_doc_verification` function; fallback to manual queue if API unavailable |
| Operational | ForeignDeskAgent IAM role scoped to verification workflow; branch SOP for manual fallback; CloudTrail logs verification result per booking |

---

### Example 3: Branch Staff Access at Menlyn Branch

| Layer | What this looks like |
|-------|---------------------|
| Contextual | "Staff insider threat — agent accessing more PII than their role requires" |
| Conceptual | "Zero-trust: trust no identity implicitly — verify staff role and branch scope on every request" |
| Logical | "IAM Identity Center role scoped to BranchAgent — read/write bookings only, no bulk export, no cross-branch access" |
| Physical | "IAM Identity Center permission set: BranchAgent-Menlyn; SCPs deny bulk S3 GetObject on PII buckets" |
| Component | `aws_ssoadmin_permission_set.branch_agent` Terraform resource with inline deny policy for bulk operations |
| Operational | Quarterly access review; CloudTrail alerts on anomalous PII access volume per agent; 60-second screen lock SOP |

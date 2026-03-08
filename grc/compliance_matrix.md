# Compliance Control Mapping Matrix
## Avis Fleet & Mobility Platform

> **Purpose:** Maps regulatory obligations to technical controls
> and evidence artifacts for audit readiness.
>
> **Regulations covered:** POPIA · ISO 27001 (Annex A) · NIST CSF · GDPR
>
> **Evidence location:** `grc/evidence/` folder contains supporting artifacts

---

## How Auditors Use This Document

An ISO 27001 auditor will ask: *"Show me how you comply with control A.10.1.1"*
This matrix is your answer: it maps the control to the specific AWS configuration
and points to evidence they can inspect.

A POPIA Information Regulator will ask: *"How do you protect personal information
as required by Section 19?"* This matrix shows the full technical safeguard chain.

---

## POPIA (Protection of Personal Information Act — South Africa)

| POPIA Section | Obligation | Technical Control Implemented | AWS Implementation | Evidence Artifact |
|---------------|-----------|-------------------------------|-------------------|-------------------|
| **s19 — Security Safeguards** | Responsible party must secure personal info against loss, damage, or unlawful access | KMS encryption for all PII; VPC isolation of Aurora database; Cognito Advanced Security Mode; GuardDuty anomaly detection; WAF on API | KMS CMK `alias/avis/pii` with rotation; Aurora in private subnet, SG allows only app-tier; GuardDuty detector enabled; WAF ACL attached to API Gateway | `grc/evidence/kms_config.md`; Aurora SG rules in Terraform; GuardDuty detector ID |
| **s19(2) — Integrity and Confidentiality** | Measures must prevent unauthorised or unlawful processing and accidental loss | TLS 1.3 enforcement on all endpoints; IAM least-privilege roles; CloudTrail audit logging; S3 Object Lock for audit immutability | CloudFront security policy: TLS 1.2 minimum (enforce 1.3 via custom policy); IAM permission boundaries; CloudTrail multi-region trail; S3 COMPLIANCE mode Object Lock | CloudTrail config (validation=true); IAM policy JSON; ACM certificate |
| **s23 — Breach Notification (72h SLA)** | Notify Information Regulator + data subjects within 72 hours of discovering a breach | GuardDuty High findings trigger EventBridge → SNS → SOC email + PagerDuty within 15 minutes; IR-001 playbook includes 72h notification SLA | GuardDuty finding publishing frequency: 15 minutes; EventBridge rule: severity ≥ HIGH; SNS topic: security-alerts; IR-001 step 5: notification workflow | `incident-response/playbook_IR-001_data_breach.md`; EventBridge rule config |
| **s14 — Data Subject Rights** | Right to access, correction, objection, and deletion of personal data | Data subject request process via customer portal; DynamoDB TTL for session deletion; S3 lifecycle for data deletion after retention period; Cognito user deletion API | Cognito: DeleteUser API; DynamoDB TTL attribute on session records; S3 lifecycle rule: delete after 7 years; POPIA consent attribute in Cognito user pool | `grc/popia_data_inventory.md`; DynamoDB TTL config; Cognito schema |
| **s11 — Consent** | Processing requires a lawful basis (consent, contract, legal obligation) | POPIA consent flag stored in Cognito user pool attribute; consent timestamp logged at registration; consent withdrawal triggers account deletion workflow | Cognito custom attribute: `custom:popia_consent` (Boolean); registration Lambda records consent timestamp to audit log; consent withdrawal: automated account deletion | Cognito schema config; Lambda registration code; audit log sample |
| **s26 — Cross-border Transfer** | Personal data may only be transferred outside SA under specific conditions | All PII data stored in `af-south-1` (Cape Town) AWS region; no cross-region replication of PII without separate DPIA | AWS region: af-south-1 for all PII workloads; S3 replication disabled on PII buckets; Aurora Global Database excluded from PII tier | Terraform `provider.tf` region config; S3 bucket replication config (disabled) |

---

## ISO 27001:2022 (Annex A Controls)

| Annex A Control | Control Name | Implementation | AWS Service / Config | Evidence |
|-----------------|-------------|----------------|----------------------|---------|
| **A.5.15** | Access Control Policy | Role-based access enforced via IAM Identity Center; no default access; zero standing privilege for production | IAM Identity Center permission sets; SCPs deny access without assignment | IAM Identity Center config; SCP document |
| **A.5.16** | Identity Management | All human identities federated via Azure AD SAML; no local IAM users for humans; MFA enforced | IAM Identity Center + Azure AD SAML; SCP: DenyCreateAccessKeyForHumanUsers | ADR-001; SSO SAML config |
| **A.5.17** | Authentication Information | No default or shared passwords; secrets stored in Secrets Manager; credentials rotated automatically every 30 days | Secrets Manager with automatic rotation; Cognito: prevent reuse of last 12 passwords; no hardcoded credentials | Secrets Manager rotation config; Cognito password policy |
| **A.8.7** | Protection Against Malware | Container images scanned for CVEs in CI pipeline; Inspector v2 on ECS tasks; GuardDuty malware protection on EBS | AWS Inspector v2 (EC2/ECR); GuardDuty malware protection; Trivy in CI pipeline | Inspector findings dashboard; CI pipeline scan results |
| **A.8.9** | Configuration Management | Infrastructure defined as Terraform IaC; all changes via Git PR and CI pipeline; no manual console changes in production | Terraform state in S3 + DynamoDB lock; AWS Config records all resource configuration changes; SCPs restrict console-based resource creation | Terraform state bucket; AWS Config configuration recorder |
| **A.8.12** | Data Leakage Prevention | Macie monitors S3 buckets for PII outside designated buckets; API response filtering strips fields not needed by each consumer | AWS Macie on all S3 buckets; API Gateway response transformation; field-level access control in Lambda authoriser | Macie job config; API Gateway response templates |
| **A.8.24** | Use of Cryptography | All data at rest encrypted with KMS CMK; TLS 1.3 in transit; key rotation enforced; no weak algorithms (MD5, SHA-1, DES) | KMS CMKs per classification with annual rotation; ACM TLS policies; API Gateway: TLS 1.2 minimum (enforce 1.3) | KMS key rotation config; ACM certificate policy; `kms_key_set` Terraform module |
| **A.8.25** | Secure Development Lifecycle | Security requirements defined before development (see `security-by-design/`); SAST in CI pipeline; dependency scanning; IaC scanning | Semgrep SAST; Snyk dependency scan; tfsec/Checkov IaC scan; all in CI pipeline | `.github/workflows/security-pipeline.yml`; scan results |
| **A.8.16** | Monitoring Activities | CloudTrail logs all API calls; GuardDuty analyses VPC Flow Logs + CloudTrail + DNS; Security Hub aggregates findings; CloudWatch alarms on anomalies | CloudTrail multi-region trail; GuardDuty detector; Security Hub standards (CIS + FSBP); CloudWatch metric alarms | CloudTrail config; GuardDuty detector ID; Security Hub scores |

---

## NIST Cybersecurity Framework (CSF) v2.0

| CSF Function | Category | Subcategory | Implementation | Maturity |
|-------------|----------|-------------|----------------|---------|
| **Identify** | Asset Management | ID.AM-1: Physical/software assets inventoried | AWS Config records all AWS resource inventory in real-time | ✅ Implemented |
| **Identify** | Risk Assessment | ID.RA-1: Vulnerabilities identified and documented | STRIDE threat register (14 threats); quarterly penetration testing; Inspector v2 continuous scanning | ✅ Implemented |
| **Protect** | Identity Management | PR.AC-1: Identities managed for authorised users | IAM Identity Center + Cognito; MFA enforced; no shared credentials | ✅ Implemented |
| **Protect** | Access Control | PR.AC-3: Remote access managed | SSM Session Manager replaces SSH; VPN not required; all sessions logged | ✅ Implemented |
| **Protect** | Data Security | PR.DS-1: Data at rest protected | KMS CMK per classification; Aurora encryption; S3 SSE-KMS | ✅ Implemented |
| **Protect** | Data Security | PR.DS-2: Data in transit protected | TLS 1.3 enforced; no unencrypted endpoints; VPC endpoints eliminate internet exposure | ✅ Implemented |
| **Protect** | Protective Technology | PR.PT-1: Audit logs protected | CloudTrail with log file validation; S3 Object Lock COMPLIANCE 7 years | ✅ Implemented |
| **Detect** | Anomalies and Events | DE.AE-2: Detected events analysed | GuardDuty ML anomaly detection; Security Hub finding correlation; CloudWatch metric alarms | ✅ Implemented |
| **Detect** | Continuous Monitoring | DE.CM-1: Network monitored | GuardDuty VPC Flow Log analysis; VPC Flow Logs to S3 + CloudWatch | ✅ Implemented |
| **Respond** | Response Planning | RS.RP-1: Response plan executed during/after incident | IR-001 playbook; SOC runbooks; EventBridge → SNS alerting chain | ⚠️ Defined, testing pending |
| **Recover** | Recovery Planning | RC.RP-1: Recovery plan executed during/after incident | Aurora automated backups; RTO <4h, RPO <1h; quarterly DR tests | ⚠️ Defined, testing pending |

---

## GDPR (relevant for EU customers and data flows)

| GDPR Article | Requirement | Implementation | Notes |
|-------------|-------------|----------------|-------|
| **Art. 5(1)(c) — Data Minimisation** | Collect only data adequate and relevant to the purpose | API response filtering; Cognito schema collects email, phone, POPIA consent only — no unnecessary attributes | Field-level filtering in Lambda authoriser per partner scope |
| **Art. 25 — Data Protection by Design** | Embed privacy controls from the design stage | SABSA Contextual layer documents privacy as architecture driver; data minimisation in API layer; pseudonymisation in data tier | Documented in `architecture/sabsa_matrix.md` Conceptual layer |
| **Art. 32 — Security of Processing** | Implement appropriate technical and organisational measures | Full encryption chain (KMS + TLS 1.3); IAM least privilege; VPC isolation; CloudTrail audit; Security Hub monitoring | Maps directly to ISO 27001 A.8.24 — controls serve both obligations |
| **Art. 33 — Breach Notification (72h)** | Notify supervisory authority within 72 hours of becoming aware of a breach | Same GuardDuty → EventBridge → SNS chain as POPIA s23; IR-001 playbook has GDPR notification template | Shared notification workflow covers both POPIA and GDPR obligations |

---

## Control Coverage Summary

| Regulation | Total Controls Mapped | Implemented | In Progress | Not Started |
|-----------|----------------------|-------------|-------------|-------------|
| POPIA | 6 | 5 | 1 | 0 |
| ISO 27001 Annex A | 9 | 9 | 0 | 0 |
| NIST CSF | 11 | 9 | 2 | 0 |
| GDPR | 4 | 4 | 0 | 0 |
| **Total** | **30** | **27** | **3** | **0** |
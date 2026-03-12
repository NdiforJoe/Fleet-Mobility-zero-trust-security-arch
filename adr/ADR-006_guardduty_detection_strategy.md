# ADR-006: GuardDuty as Primary Threat Detection Layer

| Field | Value |
|-------|-------|
| Status | Accepted |
| Date | 2025-Q1 |
| Deciders | Security Architect, CISO, SOC Lead |
| SABSA Layer | Operational (detection and monitoring) |

---

## Context

The organisation must implement threat detection and monitoring for
the AWS environment. The SOC team is currently 3 analysts with no
dedicated SIEM tooling. Options range from AWS-native services to
enterprise SIEM platforms. The chosen approach must be operational
within the project timeline and provide adequate coverage for the
NIST CSF Detect function and ISO 27001 A.12.4 requirements.

## Decision

Deploy GuardDuty as the primary threat detection engine for AWS-native
threats, with Security Hub as the aggregation and compliance scoring
plane. EventBridge routes Critical and High findings to SNS → SOC
team. Custom CloudWatch metric filters cover application-layer anomalies
not visible to GuardDuty. A Phase 2 SIEM integration (Splunk or
Microsoft Sentinel) is planned but not required for initial launch.

## Rationale

- **NIST CSF DE.CM-1** (network monitoring) satisfied by GuardDuty's
  VPC Flow Log, CloudTrail, and DNS log analysis
- **ISO 27001 A.12.4.1** (event logging) satisfied by CloudTrail +
  GuardDuty findings aggregated in Security Hub
- **ML-based detection:** GuardDuty detects threats that manual rules
  miss — DNS exfiltration, cryptomining, credential exposure on public
  repositories — via machine learning trained on global AWS threat data
- **Zero operational overhead:** No infrastructure to deploy, patch,
  or scale — GuardDuty analyses existing AWS logs automatically
- **Cost-effective:** GuardDuty provides enterprise-grade detection at
  ~$200/month — a fraction of Splunk Enterprise licensing

## Consequences

**Positive:**

- Operational within hours — no configuration required beyond enabling
- Security Hub provides CIS Benchmark compliance score (target: >80%)
- EventBridge integration means SOC receives findings within 15 minutes
- Covers the full NIST CSF Detect function at AWS infrastructure layer

**Negative / Trade-offs:**

- GuardDuty detects AWS-infrastructure-layer threats only — application
  business logic abuse (e.g. a customer booking 100 vehicles) is not
  visible to GuardDuty
- Mitigation: Custom CloudWatch metric filters + Lambda-based anomaly
  detection for application-layer threats; WAF provides request-level
  visibility
- Phase 2 SIEM will correlate GuardDuty findings with application logs
  for multi-layer threat detection

## Alternatives Considered

| Option | Why Rejected |
|--------|-------------|
| Splunk SIEM (immediate) | Requires dedicated infrastructure, licensing (~$50K/year), and tuning expertise; appropriate Phase 2 when SOC matures |
| Custom CloudWatch rules only | Manual rule creation cannot replicate ML-based anomaly detection; high false-negative rate for novel attack patterns |
| Microsoft Sentinel | Strong product; preferred if organisation uses Azure — adds complexity in AWS-native environment; revisit if hybrid strategy adopted |

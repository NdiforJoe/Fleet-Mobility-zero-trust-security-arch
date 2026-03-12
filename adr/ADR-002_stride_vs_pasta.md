# ADR-002: STRIDE as Primary Threat Modelling Methodology

| Field | Value |
|-------|-------|
| Status | Accepted |
| Date | 2025-Q1 |
| Deciders | Security Architect |
| SABSA Layer | Conceptual (defines risk identification approach) |

---

## Context

The Security Architect must select a threat modelling methodology for the
fleet platform. Two primary candidates were evaluated. The choice affects how
threats are catalogued, how development teams participate in threat modelling
workshops, and how findings are communicated to the risk register.

## Decision

Adopt STRIDE as the primary threat modelling methodology for all components,
supplemented by PASTA risk scoring for the payment processing boundary
(highest-risk, warranting deeper analysis). STRIDE is applied per component
and per trust boundary crossing.

## Rationale

STRIDE is chosen for the following reasons:

- **Developer-accessible:** The six categories (Spoofing, Tampering,
  Repudiation, Information Disclosure, Denial of Service, Elevation of
  Privilege) are concrete and actionable — a backend developer can apply
  them without deep security expertise
- **Tool support:** Maps directly to OWASP Threat Dragon (open source),
  enabling visual DFD-linked threat modelling in the repo
- **Exhaustive for this domain:** The six categories cover all threat types
  relevant to API, data store, IoT, and integration components
- **Structured workshops:** Running "STRIDE-per-component" produces consistent,
  comparable threat registers across teams

PASTA (Process for Attack Simulation and Threat Analysis) provides richer
business risk context but requires 7 stages per scope, making it impractical
for 10+ components within the project timeline.

## Consequences

**Positive:**

- Consistent threat register format that all architects can contribute to
- Threat register directly traceable to AWS controls (see STRIDE register)
- STRIDE categories map cleanly to OWASP Top-10 API risks

**Negative / Trade-offs:**

- STRIDE does not natively include probability scoring — compensated by
  adding Likelihood/Impact columns to the register manually
- STRIDE can miss complex multi-stage attack chains — mitigated by quarterly
  red team review to identify chained threats not visible in single-component
  STRIDE analysis

## Alternatives Considered

| Option | Why Rejected |
|--------|-------------|
| PASTA (primary) | 7-stage process; too time-intensive for all components; retained for payment boundary deep-dive only |
| OCTAVE | Organisationally oriented; better for enterprise risk assessment than component-level threat modelling |
| LINDDUN | Privacy-specific; useful supplement for POPIA data flows but does not cover availability or privilege threats |
| Attack trees | Good for specific high-value targets; lacks the systematic coverage of STRIDE across all components |

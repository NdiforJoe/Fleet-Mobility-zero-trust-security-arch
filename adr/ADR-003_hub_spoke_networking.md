# ADR-003: Hub-Spoke VPC Topology with Transit Gateway

| Field | Value |
|-------|-------|
| Status | Accepted |
| Date | 2025-Q1 |
| Deciders | Security Architect, Cloud Architect, Network Engineer |
| SABSA Layer | Physical (network security control) |

---

## Context

The network architecture must isolate three workload environments
(application, data, fleet/IoT) while enabling centralised security
monitoring and shared egress control. The zero-trust mandate requires
that compromise of any one tier cannot automatically lead to lateral
movement into another tier. Three topology options were evaluated.

## Decision

Implement hub-spoke topology with AWS Transit Gateway as the central hub,
three spoke VPCs (app, data, fleet), and all inter-VPC traffic transiting
the hub for inspection. Spoke-to-spoke direct routing is explicitly
prohibited via Transit Gateway route tables. A centralised egress VPC in
the hub provides inspected internet egress via NAT Gateway.

## Rationale

Hub-spoke directly implements zero-trust Pillar 3 (Network Verification):

- **No lateral movement:** Compromise of the app VPC gives an attacker
  no direct network path to the data VPC — all traffic must traverse the
  hub, where GuardDuty and VPC Flow Logs provide visibility
- **Centralised inspection point:** All east-west traffic passes through
  the hub, making anomaly detection effective and scalable
- **SABSA Physical layer principle:** Defence-in-depth at the network layer
  — NACLs at spoke boundaries + Security Groups within spokes + Transit
  Gateway route table isolation = three independent layers

## Consequences

**Positive:**

- Clear security boundary between PII data tier and other workloads
- Transit Gateway route tables are the authoritative source of truth for
  permitted network flows
- Scales to additional spoke VPCs (new environments, new services) without
  topology changes

**Negative / Trade-offs:**

- Transit Gateway costs ~$0.05/attachment/hour + $0.02/GB data processed
  (~$80-100/month for 3 spokes at demo scale)
- Added latency of ~1ms for inter-spoke calls via TGW — acceptable for
  async fleet telemetry; negligible for synchronous booking API calls
- Mitigation: Cost justified by security value; accepted by CISO

## Alternatives Considered

| Option | Why Rejected |
|--------|-------------|
| Flat single VPC | No tier isolation; SQL injection on app tier immediately has database network access; fails zero-trust micro-segmentation |
| Full-mesh VPC peering | Non-transitive; 3 VPCs = 3 peering connections, 10 VPCs = 45; does not scale and cannot provide centralised inspection point |
| AWS PrivateLink only | Too coarse for general inter-service communication; appropriate supplement for specific service endpoints (used in addition to hub-spoke) |

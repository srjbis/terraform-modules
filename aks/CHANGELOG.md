# Changelog

## 2.0.0

- AKS now calls the standalone network module to create its VNet and subnet.
- Use a user-assigned cluster identity with Network Contributor permission before cluster creation.
- Add network CIDR guardrails, outputs and composition tests.
- Breaking: replaces Azure-managed networking with an explicit subnet and changes cluster identity. Review replacement/rotation plans; v1 callers should retain their existing tag until migration is planned.

## 1.0.0

- Initial AKS module with managed identity, Entra integration, Azure RBAC, private API defaults, workload identity and Azure Policy.
- Autoscaled Linux system pool and Azure CNI overlay with Calico policy support.
- Input guardrails, mocked positive/negative tests, example, and CI checks.

# AKS module

Creates a VNet/subnet through the sibling network module, a cluster identity and network role assignment, then AKS with its required autoscaled Linux system pool in an existing resource group. Requires Terraform >= 1.9, < 2 and AzureRM >= 4.43, < 5. Configure AzureRM and authentication in the caller.

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "aks" {
  source = "git::https://github.com/srjbis/terraform-modules.git//aks?ref=aks-v2.0.0"

  name                   = "aks-platform"
  resource_group_name    = "rg-platform"
  location               = "eastus2"
  dns_prefix             = "aks-platform"
  admin_group_object_ids = var.admin_group_object_ids
  system_node_pool = {
    vm_size   = "Standard_D4s_v5"
    min_count = 2
    max_count = 5
    zones     = ["1", "2", "3"]
  }
  tags = { environment = "production" }
}
```

The tag must be published before the Git source can resolve. Git authentication is required if the repository is private; never embed credentials in source URLs. See the runnable [private example](examples/private/main.tf) and [release procedure](../RELEASING.md).

## Behavior and scope

The API is private by default, with Azure-managed private DNS. Access requires routing and DNS resolution to the created VNet (for example a connected administrative host). Public FQDN and remote run-command access are disabled. The module uses a user-assigned identity, Entra authentication, Azure RBAC, disabled local accounts, Azure Policy, OIDC and workload identity. Administrator groups must exist in the subscription tenant. Callers manage additional Azure role assignments; ordinary users typically need the Cluster User role to retrieve credentials plus appropriate AKS data-plane roles.

The network module creates a VNet named after the cluster and a subnet (default nodes) in the supplied resource group. AKS creates its managed node resource group. Networking uses Azure CNI overlay, Calico policy support and a Standard load balancer for egress. The service CIDR is 10.1.0.0/16 (DNS 10.1.0.10), and pod CIDR is 10.244.0.0/16. VNet overlap with either range is rejected. Other CIDR syntax/containment guardrails come from the network module. Size subnets for all nodes plus scale-out/rotation and check overlap with connected networks.

The user-assigned identity receives Network Contributor on the VNet before AKS creation. The Terraform caller needs permission to create identities and role assignments, in addition to network/AKS resources. Azure authorization propagation can take time even after the role assignment exists. The module does not create peering, custom private DNS zones, monitoring workspaces or workload NetworkPolicy rules. Azure Policy enables the add-on; organizational assignments remain caller-managed. Use the separate node-pool module for additional pools.

The system pool uses Ubuntu and autoscaling. Terraform does not manage the live desired node count; it manages the minimum and maximum. The temporary pool name `rotation` is reserved for resize/rotation operations, which may disrupt workloads and require spare capacity. Node OS updates use NodeImage. Kubernetes control-plane upgrades remain caller-managed; null version asks Azure for its recommended version at creation, and does not configure automatic control-plane upgrades.

For an explicitly public endpoint:

```hcl
api_access = {
  private_cluster_enabled = false
  authorized_ip_ranges    = ["203.0.113.8/32"] # Replace with your actual outbound public IP.
}
```

## Inputs

Required inputs reject null. Inputs with non-null defaults use those defaults when explicitly null; optional nested fields also use their defaults when null. `kubernetes_version` may remain null.

| Input | Default | Guardrail |
| --- | --- | --- |
| `name` | Required | 1-63 alphanumeric, underscore or hyphen; alphanumeric ends |
| `resource_group_name` | Required | 1-90 ASCII letters/digits, `_().-`; no trailing period |
| `location` | Required | Lowercase region identifier; no static region allowlist |
| `dns_prefix` | Required | 1-54 alphanumeric or hyphen; alphanumeric ends |
| `admin_group_object_ids` | Required | Nonempty set of UUID strings |
| `kubernetes_version` | `null` | `1.minor` or `1.minor.patch` syntax |
| `sku_tier` | `Standard` | `Free` or `Standard` |
| `api_access` | `{}` | Private by default; public requires IPv4 CIDRs, no /0; private forbids public ranges |
| `system_node_pool` | `{}` | Fields below |
| `network` | `{}` | address_space default 10.0.0.0/16, subnet_prefix default 10.0.0.0/22, subnet_name default nodes; canonical contained IPv4 CIDRs and no overlap with pod/service CIDRs |
| `tags` | `{}` | At most 50; nonempty keys <=512 characters, Azure-reserved key characters rejected; non-null values <=256 |

`system_node_pool` fields:

| Field | Default | Guardrail |
| --- | --- | --- |
| `name` | `system` | 1-12 lowercase letters/digits, letter first; not `rotation` |
| `vm_size` | `Standard_D4s_v5` | `Standard_` SKU syntax |
| `min_count` | `2` | Integer >=1 and <=max_count |
| `max_count` | `5` | Integer >=min_count and <=1000 |
| `zones` | `[]` | Set containing only `1`, `2`, `3`; empty means no explicit zone selection |

Validation intentionally enforces a supported subset of Azure options. It catches malformed values and contradictory combinations, but cannot verify group/resource existence, regional Kubernetes versions, VM system-pool suitability, zones, quotas, capacity, or caller permissions. Azure validates those during a real deployment. UUID format alone does not prove an administrator group exists.

## Outputs

`id`, `name`, `node_resource_group`, `oidc_issuer_url`, `identity_principal_id`, `kubelet_identity`, `network_id` and `subnet_id`. The identity output now refers to the user-assigned identity. Kubeconfig and credentials are not exported. Terraform state still contains provider-returned cluster data; store it in a protected backend.

## Migrating from v1

Version 2 changes identity and networking from Azure-managed defaults to explicit module-owned resources. Keep existing deployments pinned to aks-v1.0.0 until you review a migration plan. A source-only upgrade can cause replacement or pool rotation; do not assume an in-place migration. There is no automatic state move from the old Azure-managed network because those resources were never in this module's state. For production, consider a new cluster and workload migration. If retaining a cluster, reconcile/import networking with its actual settings and review identity permissions, network profile changes and the complete Terraform plan before applying.

The initial system pool stays inside the AKS resource because AzureRM requires it. This module does not attempt to move that pool into an additional node-pool resource.

## Tests

```sh
terraform -chdir=aks init -backend=false
terraform fmt -check -recursive
terraform -chdir=aks validate
terraform -chdir=aks test
```

Run from the repository root. Tests mock AzureRM, require no Azure credentials and provision no Azure resources. They assert secure defaults, public allowlists, custom pool mapping, outputs and rejected values including null collection entries and numeric boundaries. CI also validates the example. Mock tests do not prove Azure deployment or connectivity; see the manual acceptance steps in the release procedure.

Reference: [AzureRM AKS resource](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster), [Terraform test framework](https://developer.hashicorp.com/terraform/language/tests), and [provider mocking](https://developer.hashicorp.com/terraform/language/tests/mocking).

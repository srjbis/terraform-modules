# AKS module

Creates a VNet/subnet through the sibling network module, a cluster identity and network role assignment, then AKS with its required Linux system pool in an existing resource group. All cluster settings are configurable with the existing secure/autoscaling defaults. Requires Terraform >= 1.9, < 2 and AzureRM >= 4.43, < 5. Configure AzureRM and authentication in the caller.

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "aks" {
  source = "git::https://github.com/srjbis/terraform-modules.git//aks?ref=aks-v2.1.0"

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

The API is private by default, with Azure-managed private DNS. Access requires routing and DNS resolution to the created VNet (for example a connected administrative host). Defaults disable public FQDN and remote run-command access, and enable a user-assigned identity, Entra authentication, Azure RBAC, disabled local accounts, Azure Policy, OIDC and workload identity. These settings can be overridden using the inputs below. Administrator groups must exist in the subscription tenant. Callers manage additional Azure role assignments; ordinary users typically need the Cluster User role to retrieve credentials plus appropriate AKS data-plane roles.

The network module creates a VNet named after the cluster and a subnet (default nodes) in the supplied resource group. AKS creates its managed node resource group. Networking defaults to Azure CNI overlay, Calico policy and a Standard load balancer for egress. Default service CIDR is 10.1.0.0/16 (DNS 10.1.0.10), and default pod CIDR is 10.244.0.0/16. Set network_profile to override them. Validation rejects overlap between active ranges and verifies DNS membership. Size subnets and pod ranges for all nodes plus scale-out/rotation, and check overlap with connected networks.

The default user-assigned identity receives Network Contributor on the VNet before AKS creation. With SystemAssigned, the principal and role assignment can only be created after AKS; dependent node pools wait for that assignment. The Terraform caller needs permission to create identities and role assignments, in addition to network/AKS resources. Azure authorization propagation can take time even after an assignment exists. Custom private DNS zone IDs require UserAssigned identity; the module grants Private DNS Zone Contributor on that existing zone. It does not create the custom zone, peering, monitoring or workload NetworkPolicy rules. DNS zone naming, links and cross-subscription permissions must meet Azure requirements.

The system pool defaults to Ubuntu and autoscaling. With autoscaling enabled, node_count is omitted and the autoscaler owns the desired count. With autoscaling disabled, Terraform manages node_count, including subsequent resizes. The configurable temporary pool name defaults to rotation and must differ from the system pool name. Rotation may disrupt workloads and requires spare capacity. Node OS updates default to NodeImage. Kubernetes control-plane upgrades remain caller-managed; null version asks Azure for its recommended version at creation and does not enable automatic control-plane upgrades.

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
| `name` | `system` | 1-12 lowercase letters/digits, letter first; different from rotation name |
| `vm_size` | `Standard_D4s_v5` | `Standard_` SKU syntax |
| `min_count` | `2` | Integer >=1 and <=max_count |
| `max_count` | `5` | Integer >=min_count and <=1000 |
| `zones` | `[]` | Set containing only `1`, `2`, `3`; empty means no explicit zone selection |
| `temporary_name_for_rotation` | `rotation` | 1-12 lowercase letters/digits, letter first; different from pool name |
| `auto_scaling_enabled` | `true` | Boolean; false selects fixed node_count and omits min/max from the resource |
| `node_count` | `2` | Integer 1-1000; used only when autoscaling is false |
| `os_sku` | `Ubuntu` | Ubuntu or AzureLinux |
| `node_public_ip_enabled` | `false` | Boolean |

Additional top-level settings:

| Input | Default | Guardrail |
| --- | --- | --- |
| `private_cluster_public_fqdn_enabled` | `false` | Requires private cluster |
| `private_dns_zone_id` | `System` | System, None, or existing DNS zone resource ID; applied only to private clusters |
| `role_based_access_control_enabled` | `true` | Disabling also requires azure_rbac_enabled=false and local_account_disabled=false; omits Entra integration |
| `azure_rbac_enabled` | `true` | Requires Kubernetes RBAC; false uses Kubernetes authorization with Entra authentication |
| `local_account_disabled` | `true` | Requires Kubernetes RBAC/Entra integration |
| `azure_policy_enabled` | `true` | Boolean |
| `oidc_issuer_enabled` | `true` | Boolean |
| `workload_identity_enabled` | `true` | Requires OIDC |
| `run_command_enabled` | `false` | Boolean |
| `node_os_upgrade_channel` | `NodeImage` | None, Unmanaged, SecurityPatch, NodeImage |
| `identity_type` | `UserAssigned` | UserAssigned or SystemAssigned |

Private DNS None requires private_cluster_public_fqdn_enabled=true because this module does not configure custom DNS servers. Existing custom DNS zones require a private cluster and UserAssigned identity.

`network_profile` fields (object defaults to `{}`):

| Field | Default | Guardrail |
| --- | --- | --- |
| `network_plugin` | `azure` | azure or kubenet |
| `network_plugin_mode` | `overlay` | overlay or none; overlay requires azure |
| `network_policy` | `calico` | calico, azure, cilium, none; azure requires flat Azure CNI |
| `network_data_plane` | `azure` | azure or cilium; cilium requires Azure overlay and cilium/none policy |
| `load_balancer_sku` | `standard` | standard only; Basic is retired for AKS |
| `outbound_type` | `loadBalancer` | loadBalancer or userAssignedNATGateway |
| `service_cidr` | `10.1.0.0/16` | Canonical IPv4 /13-/29, nonoverlapping with VNet and active pod range |
| `dns_service_ip` | `10.1.0.10` | Inside service_cidr; not network, broadcast or first service address |
| `pod_cidr` | `10.244.0.0/16` | Canonical IPv4 /8-/24; applied only to overlay or kubenet |

Use the string none to omit the plugin mode or policy; null optional fields use defaults. Flat Azure CNI automatically omits pod_cidr. NAT egress creates a Standard public IP, NAT gateway and associations before AKS. Managed NAT is incompatible with this module-owned VNet. Custom routes and isolated-network bootstrapping are not provided, so those outbound modes are rejected. Azure availability, capacity and CIDR sizing for actual workload/node totals remain caller responsibilities.

Example overrides (all omitted settings keep their existing defaults):

```hcl
node_os_upgrade_channel = "SecurityPatch"
system_node_pool = {
  auto_scaling_enabled        = false
  node_count                  = 3
  temporary_name_for_rotation = "rolling"
}
network_profile = {
  service_cidr   = "172.21.0.0/16"
  dns_service_ip = "172.21.0.53"
  pod_cidr       = "172.22.0.0/16"
}
```

Validation intentionally enforces a supported subset of Azure options. It catches malformed values and contradictory combinations, but cannot verify group/resource existence, regional Kubernetes versions, VM system-pool suitability, zones, quotas, capacity, or caller permissions. Azure validates those during a real deployment. UUID format alone does not prove an administrator group exists.

## Outputs

`id`, `name`, `node_resource_group`, `oidc_issuer_url`, `identity_principal_id`, `kubelet_identity`, `network_id` and `subnet_id`. The identity output refers to the selected identity type. Kubeconfig and credentials are not exported. Terraform state still contains provider-returned cluster data; store it in a protected backend.

Version 2.1 preserves existing defaults and includes moved blocks for the conditional user identity and network role assignment. Their state addresses gain [0] without recreation under the default configuration. Review actual plans before changing identity, network modes, CIDRs, DNS or pool sizing.

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

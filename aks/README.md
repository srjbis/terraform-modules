# AKS module

Creates one AKS cluster and one autoscaled Linux system pool in an existing resource group. Requires Terraform >= 1.9, < 2 and AzureRM >= 4.43, < 5. Configure the provider and Azure authentication in the calling root module.

```hcl
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

module "aks" {
  source = "git::https://github.com/srjbis/terraform-modules.git//aks?ref=aks-v1.0.0"

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

The API is private by default, with Azure-managed private DNS. Access requires network routing and DNS resolution to the cluster's managed virtual network (for example a connected administrative host). Public FQDN and remote run-command access are disabled. The module uses system-assigned identity, Entra authentication, Azure RBAC, disabled local accounts, Azure Policy, OIDC and workload identity. Administrator groups must exist in the subscription tenant. Callers manage any additional Azure role assignments; ordinary users typically need the Cluster User role to retrieve credentials plus appropriate AKS data-plane roles.

Azure creates the node resource group, virtual network and address ranges. Networking uses Azure CNI overlay, Calico network policy support, and a Standard load balancer for outbound traffic. No custom subnet, peering, custom CIDRs, private DNS zones, user node pools or monitoring workspace is managed by this initial module. Check address overlap before connecting networks. Network policy support does not create workload NetworkPolicy rules; callers must deploy those policies. Azure Policy enables the add-on; organizational policy assignments are caller-managed.

The system pool uses Ubuntu and autoscaling. Terraform does not manage the live desired node count; it manages the minimum and maximum. The temporary pool name `rotation` is reserved for resize/rotation operations, which may disrupt workloads and require spare capacity. Node OS updates use NodeImage. Kubernetes control-plane upgrades remain caller-managed; null version asks Azure for its recommended version at creation, and does not configure automatic control-plane upgrades.

For an explicitly public endpoint:

```hcl
api_access = {
  private_cluster_enabled = false
  authorized_ip_ranges    = ["203.0.113.8/32"] # Replace with your actual outbound public IP.
}
```

## Inputs

All top-level inputs except `kubernetes_version` reject null; optional nested fields use their defaults when null.

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

`id`, `name`, `node_resource_group`, `oidc_issuer_url`, `identity_principal_id`, and `kubelet_identity`. Kubeconfig and credentials are not exported. Terraform state still contains provider-returned cluster data; store it in a protected backend.

## Tests

```sh
terraform -chdir=aks init -backend=false
terraform fmt -check -recursive
terraform -chdir=aks validate
terraform -chdir=aks test
```

Run from the repository root. Tests mock AzureRM, require no Azure credentials and provision no Azure resources. They assert secure defaults, public allowlists, custom pool mapping, outputs and rejected values including null collection entries and numeric boundaries. CI also validates the example. Mock tests do not prove Azure deployment or connectivity; see the manual acceptance steps in the release procedure.

Reference: [AzureRM AKS resource](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster), [Terraform test framework](https://developer.hashicorp.com/terraform/language/tests), and [provider mocking](https://developer.hashicorp.com/terraform/language/tests/mocking).

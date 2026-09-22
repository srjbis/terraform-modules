# Node-pool module

Creates an autoscaled Linux user pool. Supply exactly one of `existing_aks` or `aks`.

| Input selection | What happens |
| --- | --- |
| `existing_aks = { id = "..." }` | Reads and verifies that cluster in Azure, then attaches the pool. Creates no AKS or network. |
| `aks = { ... }`, existing_aks omitted | Calls AKS, which creates its network; then creates the additional pool. |
| Both or neither | Validation error |
| Supplied AKS ID not found or unreadable | Azure data-source error; no fallback creation |

Selection is based on supplied input, not a name search. Keep object presence known at plan time; the ID itself can be another module's output. Configure AzureRM for the same subscription as the ID. A postcondition verifies the lookup returns exactly that ID. Existing pools must use VM scale sets. Existing mode reuses the first returned pool's subnet, or Azure's default if that subnet is absent; clusters needing other network layouts require a tailored configuration.

## Existing AKS

```hcl
module "apps" {
  source = "git::https://github.com/srjbis/terraform-modules.git//node-pool?ref=node-pool-v1.1.0"

  name         = "apps"
  existing_aks = { id = var.aks_id }
  scaling      = { min_count = 0, max_count = 5 }
}
```

See [existing-cluster example](examples/existing-aks/main.tf). The cluster stays outside this module's ownership. Destroying this module removes only its pool in this mode. Choose a pool name and rotation name (`name` + `r`) unused by other pools. An already-existing pool requires explicit Terraform import, not implicit adoption. The lookup may include this module's pool on subsequent plans, which is allowed.

## New AKS and network

```hcl
module "apps" {
  source = "git::https://github.com/srjbis/terraform-modules.git//node-pool?ref=node-pool-v1.1.0"

  name = "apps"
  aks = {
    name                   = "aks-platform"
    resource_group_name    = "rg-platform"
    location               = "eastus2"
    dns_prefix             = "aks-platform"
    admin_group_object_ids = var.admin_group_object_ids
    network = {
      address_space = "172.20.0.0/16"
      subnet_prefix = "172.20.0.0/22"
    }
  }
}
```

See [new-cluster example](examples/new-aks/main.tf). This mode owns all three layers: destroying the module removes its pool, AKS, identity/role assignment and network. Switching modes after deployment is a state migration, not adoption; review the plan before changing selection. Use the created cluster's output ID in separate existing-mode module calls to add further pools.

## Inputs and guardrails

| Input | Default | Validation |
| --- | --- | --- |
| `name` | Required | 1-11 lowercase alphanumeric, letter first; rotation and rotatio reserved; new system-pool collisions rejected |
| `existing_aks` | `null` | Full AKS ID including subscription UUID; exclusive with aks |
| `aks` | `null` | Creation object below; exclusive with existing_aks |
| `vm_size` | `Standard_D4s_v5` | Standard_ SKU syntax |
| `scaling` | `{}` | Integer min_count (default 1), max_count (default 5); 0 <= min <= max, 1 <= max <=1000 |
| `zones` | `[]` | Set containing only 1, 2, 3; null elements rejected |
| `tags` | `{}` | <=50 valid keys; non-null values <=256 characters; passed to any newly created AKS/network |

The `aks` object requires `name`, `resource_group_name`, `location`, `dns_prefix`, `admin_group_object_ids`. It accepts all optional AKS inputs: `kubernetes_version`, `sku_tier`, `api_access`, `system_node_pool`, `network`, `network_profile`, `identity_type`, `private_dns_zone_id`, `private_cluster_public_fqdn_enabled`, `role_based_access_control_enabled`, `azure_rbac_enabled`, `local_account_disabled`, `azure_policy_enabled`, `oidc_issuer_enabled`, `workload_identity_enabled`, `run_command_enabled`, `node_os_upgrade_channel`. Defaults and guardrails are delegated to [AKS](../aks/README.md). Supply tags at this module's top level. The initial system pool may be fixed-size; the additional user pool remains autoscaled. Azure checks region/SKU support, permissions, quotas and capacity. Size subnets for all pools, scale-out and rotation.

The additional pool always uses Linux/Ubuntu, User mode and autoscaling. Node public IPs are disabled. Desired node count belongs to the autoscaler. Rotation uses `name` + `r` (up to 12 characters) and can disrupt workloads. The initial system pool remains inside AKS as required by AzureRM.

Outputs: `id`, `name`, `aks_id`, `created_aks`, `subnet_id`, `network_id` (null when reusing AKS).

## Tests and examples

```sh
terraform -chdir=node-pool init -backend=false -lockfile=readonly
terraform -chdir=node-pool validate
terraform -chdir=node-pool test
```

Mocked tests cover both dependency paths, outputs, input forwarding, and invalid selection, IDs, names, scaling, zones, tags and incompatible clusters. CI validates both examples. A missing-cluster API error requires real Azure integration testing; mocks do not emulate HTTP failures. Run examples with your subscription ID and existing AKS ID or real Entra groups. Review a real plan and destroy test resources after use. See [acceptance checks](../RELEASING.md).

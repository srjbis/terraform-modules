# Terraform Azure modules

Three independently callable modules with automatic dependency composition:

| Module | Behavior | Release |
| --- | --- | --- |
| [network](network/README.md) | Creates only a VNet and subnet; no AKS dependency | `network-v1.0.0` |
| [aks](aks/README.md) | Creates network, identity/permissions, then AKS with its required system pool | `aks-v2.0.0` |
| [node-pool](node-pool/README.md) | Adds a user pool to existing AKS, or creates network and AKS first | `node-pool-v1.0.0` |

All modules require Terraform >=1.9, <2 and AzureRM >=4.43, <5. Configure AzureRM and credentials in the caller. Resource groups are caller-managed; examples create their own where needed. Each module includes guardrails, mocked tests, outputs, examples and a changelog.

## Create only a network

```hcl
module "network" {
  source = "git::https://github.com/srjbis/terraform-modules.git//network?ref=network-v1.0.0"

  name                = "vnet-platform"
  resource_group_name = "rg-platform"
  location            = "eastus2"
}
```

## Create AKS and its network

```hcl
module "aks" {
  source = "git::https://github.com/srjbis/terraform-modules.git//aks?ref=aks-v2.0.0"

  name                   = "aks-platform"
  resource_group_name    = "rg-platform"
  location               = "eastus2"
  dns_prefix             = "aks-platform"
  admin_group_object_ids = var.admin_group_object_ids
}
```

## Add a pool to existing AKS

```hcl
module "apps" {
  source = "git::https://github.com/srjbis/terraform-modules.git//node-pool?ref=node-pool-v1.0.0"

  name         = "apps"
  existing_aks = { id = var.aks_id }
}
```

## Create network, AKS and an additional pool

```hcl
module "apps" {
  source = "git::https://github.com/srjbis/terraform-modules.git//node-pool?ref=node-pool-v1.0.0"

  name = "apps"
  aks = {
    name                   = "aks-platform"
    resource_group_name    = "rg-platform"
    location               = "eastus2"
    dns_prefix             = "aks-platform"
    admin_group_object_ids = var.admin_group_object_ids
  }
}
```

`existing_aks` selects reuse when supplied; omitting it requires `aks` configuration and selects creation. A supplied ID is read from Azure, and a missing/inaccessible cluster fails instead of silently creating a replacement. The module does not perform search-by-name fallback. Existing clusters remain owned by their current state; this module owns only its additional pool.

An AKS cluster requires an initial system pool in the provider's cluster resource. The separate node-pool module creates additional user pools. Resource references establish network → AKS → pool ordering; network role assignment also has an explicit dependency before cluster creation.

AKS v2 changes networking and identity. Existing consumers should stay pinned to `aks-v1.0.0` until they review the [migration guidance](aks/README.md#migrating-from-v1). Tags are immutable. Relative sibling sources keep all dependencies in the same Git checkout/tag. See [release and testing instructions](RELEASING.md).

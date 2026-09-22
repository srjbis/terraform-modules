# Terraform modules

Reusable modules with module-specific semantic version tags.

| Module | Description | Initial release tag |
| --- | --- | --- |
| [aks](aks/README.md) | Azure Kubernetes Service with validated inputs and secure defaults | `aks-v1.0.0` |

Consumers select the module subdirectory and an immutable release tag:

```hcl
module "aks" {
  source = "git::https://github.com/srjbis/terraform-modules.git//aks?ref=aks-v1.0.0"

  name                   = "aks-platform"
  resource_group_name    = "rg-platform"
  location               = "eastus2"
  dns_prefix             = "aks-platform"
  admin_group_object_ids = ["REPLACE-WITH-EXISTING-ENTRA-GROUP-UUID"]
}
```

The resource group must already exist. Configure the AzureRM provider in the calling root module. The Git source becomes usable once the commit and tag are pushed to the remote. See [release instructions](RELEASING.md).

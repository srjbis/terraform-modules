# Network module

Creates an Azure VNet and one workload subnet in an existing resource group. It has no dependency on AKS, node pools or other modules. See the [standalone example](examples/basic/main.tf).

```hcl
module "network" {
  source = "git::https://github.com/srjbis/terraform-modules.git//network?ref=network-v1.0.0"

  name                = "vnet-platform"
  resource_group_name = "rg-platform"
  location            = "eastus2"
  address_space       = "172.20.0.0/16"
  subnet_prefix       = "172.20.0.0/22"
  subnet_name         = "nodes"
  tags                = { environment = "production" }
}
```

## Inputs and guardrails

| Input | Default | Validation |
| --- | --- | --- |
| `name` | Required | 1-64 Azure name characters; alphanumeric start; alphanumeric/underscore end |
| `resource_group_name` | Required | 1-90 supported ASCII characters; no trailing period |
| `location` | Required | Lowercase Azure region identifier |
| `address_space` | `10.0.0.0/16` | Canonical IPv4 network, /8 through /29 |
| `subnet_prefix` | `10.0.0.0/22` | Canonical IPv4 subnet contained in address_space; prefix no longer than /29 |
| `subnet_name` | `nodes` | 1-80 valid characters; Azure reserved subnet names rejected |
| `tags` | `{}` | <=50 valid keys; non-null values <=256 characters |

Required inputs reject null; optional inputs use their defaults when explicitly null. For example, `10.0.0.1/24` is rejected because it is not the network address; `10.2.0.0/24` is rejected when the VNet is `10.0.0.0/16`. CIDR restrictions are the module's supported subset. This module does not manage NSGs, routes, peering, private endpoints, NAT or external DNS. Azure verifies resource group existence, permissions and region support. Callers must size the subnet for workloads and avoid overlap with connected networks.

Outputs: `id` (VNet ID), `name`, `subnet_id`, `address_space`, `subnet_prefix`.

## Tests and example

From the repository root:

```sh
terraform -chdir=network init -backend=false -lockfile=readonly
terraform -chdir=network validate
terraform -chdir=network test
terraform -chdir=network/examples/basic init -backend=false -lockfile=readonly
terraform -chdir=network/examples/basic validate
```

Mocked tests cover standalone creation, custom CIDRs and tags, boundaries, invalid names, reserved subnet names, malformed CIDRs and containment. They create no Azure resources. To deploy the example, authenticate to Azure, pass `subscription_id` to Terraform plan, review, then apply; destroy it when finished. See [release checks](../RELEASING.md).

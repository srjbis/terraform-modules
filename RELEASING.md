# Releasing modules

Release tags are module-specific: `network-vMAJOR.MINOR.PATCH`, `aks-vMAJOR.MINOR.PATCH`, `node-pool-vMAJOR.MINOR.PATCH`. Breaking inputs/outputs or behavior require a major version; compatible additions a minor version; compatible fixes a patch. Never move existing tags. Git sources use `?ref=`, not Terraform's registry-only `version` argument. Full commit SHAs can replace tags for stronger pinning.

Relative sibling module sources resolve from the same Git checkout. Release consumers therefore receive the exact dependency versions at that tag. A network change affecting AKS or node-pool requires considering releases for all affected entry points, not only network.

## Verification

From the repository root, run formatting plus initialization, validation and tests for each module:

```sh
terraform fmt -check -recursive
terraform -chdir=network init -backend=false
terraform -chdir=network validate
terraform -chdir=network test
terraform -chdir=aks init -backend=false
terraform -chdir=aks validate
terraform -chdir=aks test
terraform -chdir=node-pool init -backend=false
terraform -chdir=node-pool validate
terraform -chdir=node-pool test
```

Also initialize and validate `network/examples/basic`, `aks/examples/private`, `node-pool/examples/existing-aks`, and `node-pool/examples/new-aks`. GitHub Actions runs the three suites and all examples on Terraform 1.9.8 and 1.15.2.

Terraform lock files and .gitignore are local-only and are not tracked in this repository. Initialization creates local lock files; CI resolves a provider matching the module constraints on each fresh checkout. To upgrade a local provider selection, run init -upgrade and rerun checks. Consumers manage their own root lock files.

For fresh clones, configure local exclusions in .git/info/exclude (or an untracked .gitignore) for .gitignore, **/.terraform.lock.hcl, **/.terraform/*, *.tfstate, *.tfstate.*, *.tfplan, *.tfvars and *.tfvars.json before staging changes. Existing release tags and historical commits retain the files originally committed; this cleanup applies to the current main branch.

## Publishing configurable AKS settings

Update changelogs, review and commit the changes, then create annotated tags for the same tested commit:

```sh
git tag -a aks-v2.1.0 -m "AKS module v2.1.0"
git tag -a node-pool-v1.1.0 -m "Node-pool module v1.1.0"
git push --atomic origin main refs/tags/aks-v2.1.0 refs/tags/node-pool-v1.1.0
```

If those tags already exist, use new versions for subsequent releases. Preserve aks-v1.0.0 for existing consumers; v2 changes cluster identity and networking. Enable branch protection requiring Terraform module checks and restrict tag updates using GitHub rulesets. Repository files alone do not configure these settings.

## Manual Azure acceptance

Mocks create no Azure resources and do not prove regional availability, permissions or API behavior. Before production use or significant provider changes, use a disposable subscription:

1. Deploy the standalone network example and verify VNet/subnet addresses.
2. Deploy the AKS example; verify subnet attachment, identity authorization, private connectivity, Entra login and a workload.
3. Deploy the existing-AKS pool example using that cluster ID. Verify only a pool is added and repeated plans do not attempt to create AKS/network or reset autoscaled counts.
4. Try a well-formed nonexistent AKS ID and confirm lookup fails before any pool is created.
5. Deploy the new-AKS pool example; verify network, identity/permissions, cluster and pool ordering.
6. Exercise overridden CIDRs, DNS, identity types, fixed-count pool resizing and NAT egress. Confirm a second plan preserves autoscaled counts. For custom DNS, verify zone permissions and resolution from the cluster network.
7. Destroy the example deployments in reverse dependency order and confirm no resources are left behind.

These acceptance tests require real subscription/group IDs, permissions to create role assignments, private network connectivity, and Azure budget. They are not run automatically by CI.

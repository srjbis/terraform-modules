# Releasing modules

AKS tags use `aks-vMAJOR.MINOR.PATCH`. Breaking input/output or behavioral changes require a major version; compatible additions a minor version; compatible fixes a patch version. Never move an existing release tag. Git sources use `?ref=`, not Terraform's registry-only `version` argument. For strongest pinning, consumers can substitute the full commit SHA for the tag.

Before each release:

```sh
terraform fmt -check -recursive
terraform -chdir=aks init -backend=false -lockfile=readonly
terraform -chdir=aks validate
terraform -chdir=aks test
terraform -chdir=aks/examples/private init -backend=false -lockfile=readonly
terraform -chdir=aks/examples/private validate
```

Update the changelog, review the diff, commit the reviewed files, and create an annotated tag. For the initial release:

```sh
git tag -a aks-v1.0.0 -m "AKS module v1.0.0"
git push origin main
git push origin aks-v1.0.0
```

If the initial tag already exists locally, only push it. Subsequent releases must use a new version. Enable branch protection requiring the Terraform AKS checks, and restrict release tag creation/updates with repository rulesets. These settings must be configured in GitHub; files in this repository do not enforce them.

The committed lock files make repository checks repeatable; Terraform consumers resolve provider constraints using their own root lock files. To upgrade the provider, run `terraform init -upgrade` in the module and example, regenerate Linux/Windows lock checksums with `terraform providers lock -platform=linux_amd64 -platform=windows_amd64`, run checks, and review both lock files.

Mock tests create no cloud resources. Before production adoption or significant provider upgrades, run the example in a disposable Azure subscription with real group IDs and regional capacity. Check private connectivity, Entra authentication, workload identity and a workload deployment; then destroy the example. This manual acceptance test incurs Azure charges and is not run by CI.

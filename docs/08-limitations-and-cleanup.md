# 08 — Limitations, security, and cleanup

## Current limitations

- This is a small learning lab, not a production architecture: no HA/SLA, autoscaling, backup/restore runbooks, centralized logging, alerting, incident response, or end-to-end monitoring.
- Defaults create one control-manager and one workload VM in one region/zone. VM maps allow more entries, but scaling, quota, routing, inventory, and failure behavior are not validated.
- Default VMs use Ubuntu 24.04 ARM64, `Standard_D2ps_v6`, zone 1. Confirm availability and quota in each subscription.
- No Public IP is provisioned. SSH administration is intended over Tailscale/private networking. The administrator public key is installed for Azure VM provisioning, but this repository does not configure or verify a separate private-key/Serial Console emergency recovery path; never open SSH to the Internet for debugging.
- Azure requires a VM authentication mechanism. This project installs the administrator public SSH key and disables password authentication. The public key is supplied to workflows as `SSH_PUBLIC_KEY`; private-key material must remain secret. `sensitive` in Terraform redacts normal CLI output but does not encrypt state.
- Terraform creates a separate internal CM-to-workload SSH key. Its private key is stored in Terraform state and delivered to the CM via custom data/cloud-init. Protect backend state, versions/backups, plans, artifacts, cloud-init data, and Azure control-plane access.
- The Ansible deployment workflow uses Tailscale OIDC plus the Tailscale SSH server/policy to reach the CM. It does not store or load the VM administrator private SSH key in GitHub CI.
- The CI workflow retains `StrictHostKeyChecking=no` for compatibility with the current automation. This disables server identity verification and is not suitable for sensitive production workloads.
- VM image version is `latest`; bootstrap and Ansible install upstream software, so rebuilds can differ over time.
- The sample app is a small HTTP responder and does not use PostgreSQL. PostgreSQL packages are installed, but database/schema/credentials/TLS/backups are not configured. Node Exporter is installed, but no Prometheus server, metrics retention, or dashboards exist.
- `ansible/group_vars/workload.yml` declares `*_enabled` flags, but current playbooks do not conditionally skip roles based on those values.
- Load Balancer resources are scaffolding: workload NICs/IP configurations are not associated with the backend pool. The frontend is private; do not enable it expecting load balancing.
- Tailscale `tag:ci` has powerful access. The current SSH policy permits both `azureadmin` and `root` on `tag:cm`, as required by the automation. Review tag ownership and access scope carefully.
- The CM clones the repository using a hard-coded HTTPS URL. Private repositories need an explicit authentication design; do not embed a PAT/token in cloud-init.
- Terraform plan summaries/artifacts may disclose topology or configuration. Restrict access and retention.
- The destroy workflow generates/displays a destroy plan, then runs a separate `terraform destroy -auto-approve`; it does not apply the saved plan. Environment approval occurs before plan generation, so it is not approval of the exact destroy diff. Use only in an isolated lab; redesign as a separate review-then-apply process before using for important environments.

## Cleanup

Cleanup has infrastructure and identity layers. Do not delete the state backend first: Terraform needs the state to delete managed resources safely. The workflow `Terraform VM Resource Destroy` removes module 02 only, and it does not apply its saved destroy plan; use it only for an isolated lab after reviewing the workflow/run target and its documented review gap.

### A. Remove the VM/network module

1. In Azure Portal, select the intended subscription and inspect the lab Resource Group. In PowerShell, verify the active subscription and resource list before dispatching anything:

```powershell
az account show --output table
az vm list --resource-group "<LAB_RESOURCE_GROUP>" --show-details --output table
az resource list --resource-group "<LAB_RESOURCE_GROUP>" --output table
```

2. In GitHub, open **Actions → Terraform VM Resource Destroy → Run workflow** on `main`. Confirm the target repository and `terraform-destroy` Environment, review the resulting run and resource target, and proceed only for the disposable lab. Remember this workflow generates/displays one destroy plan and then invokes a separate `terraform destroy -auto-approve`; the Environment approval is before plan generation and is not approval of that exact diff.
3. Verify Azure has no module-02 VMs, NICs, VNet, NSGs, or optional Load Balancer left:

```powershell
az resource list --resource-group "<LAB_RESOURCE_GROUP>" --output table
az vm list --resource-group "<LAB_RESOURCE_GROUP>" --output table
```

The `terraform/01-identity` Resource Group and `id-cm` remain. Do not delete the Resource Group manually while either Terraform root still manages it.

### B. Remove the identity foundation through its reviewed Terraform state

There is no dedicated identity-destroy workflow. The existing identity apply workflow can apply an approved plan, but `terraform/01-identity/main.tf` has `prevent_destroy = true` on the Resource Group and managed identity. Do not bypass that protection in an unreviewed edit and do not delete resources directly in Azure while they remain in Terraform state.

Use two pull requests, both reviewed by a trusted maintainer:

1. First PR: remove only the two `lifecycle { prevent_destroy = true }` blocks from the Resource Group and identity resource blocks in `terraform/01-identity/main.tf`. Keep all resource declarations. Confirm the identity plan reports no infrastructure changes; merge and approve the corresponding `terraform-identity-apply` run. This removes the Terraform guard while retaining the resources.
2. Second PR: remove the now-unneeded managed identity, its `cm_reader` role assignment, and the lab Resource Group resource declaration from `terraform/01-identity/main.tf` (and remove outputs/references that depend on those resources if present). Do not change backend settings. Before merging, open the `Terraform Identity Plan` artifact and confirm it proposes deletion only of the lab foundation resources; stop if it includes state storage, unrelated resources, or unexpected replacement/create actions.
3. Merge only after the destroy plan review, then approve `Terraform Identity Apply` in the protected environment. Verify that the apply succeeds and check the lab Resource Group in Azure:

```powershell
$groupExists = az group exists --name "<LAB_RESOURCE_GROUP>"
if ($groupExists -eq "true") {
	az resource list --resource-group "<LAB_RESOURCE_GROUP>" --output table
	az identity list --resource-group "<LAB_RESOURCE_GROUP>" --output table
} else {
	"Lab Resource Group is absent."
}
```

Expect `Lab Resource Group is absent.` If the group still exists, inspect the listed resources and do not assume cleanup completed. Because Azure may retain deleted-resource records temporarily, verify the active resource list rather than relying on historical activity records. Keep both Terraform state blobs until the decommission is verified and any required audit retention is complete.

### C. Revoke external access and remove retained artifacts

Only after the workflows no longer need these identities:

1. **Azure RBAC:** list assignments for each of the five GitHub Service Principal Object IDs at the state account, subscription, and lab resource-group scopes. Remove only the assignments that belong to this lab, by the assignment IDs returned from Azure, then list again to verify. Example:

```powershell
az role assignment list --assignee-object-id "<SP_OBJECT_ID>" --all --query "[].{id:id,role:roleDefinitionName,scope:scope}" --output table
az role assignment delete --ids "<EXACT_LAB_ROLE_ASSIGNMENT_RESOURCE_ID>"
```

Repeat for the matching assignment IDs and SPs. Do not delete a role assignment based only on a display name; confirm principal ID, role, and scope. Include the temporary identity-apply subscription assignments and local administrator state-storage assignment if they were created for this lab.
2. **Entra:** for each of the five App Registrations, list its FICs, delete the exact `github-<environment>` FIC names using the procedure in document 03, and verify they are absent. Only then delete the lab Service Principal and App Registration if they are not shared or used elsewhere. Verify the display name and object IDs before deletion; never remove a similarly named identity from another project.
3. **GitHub:** under **Settings → Environments**, remove the lab's environment secrets/variables and protection settings after no workflows need them; delete the environments if this repository will no longer use them. Under **Actions**, delete old Terraform plan artifacts and review run summaries/comments. Plan files and summaries may disclose infrastructure details even though they are not passwords. Configure a short artifact retention period and verify old artifacts are no longer downloadable.
4. **Tailscale:** in the Admin Console, revoke the policy GitOps, `tailscale-ci`, and CM workload-identity credentials created for this lab; remove any enrolled CI machines/tags that no longer exist; remove the lab tag grants and advertised-route approval only if they are not used by another device. Re-open the credential/device/policy views and verify the intended entries are gone. Do not revoke shared tailnet rules or identities without checking other consumers.
5. **Git and local copies:** inspect `git ls-files` and repository history for state, tfvars, generated inventory, private keys, JSON credential files, and plan output. Delete downloaded plan artifacts, local plan/state copies that are no longer required, and temporary files. If a sensitive item was ever committed, rotate/revoke it first and follow reviewed Git-history remediation; `.gitignore` does not erase history. Deleting a file from OneDrive/SSD is not guaranteed secure erasure—also review OneDrive recycle bin/version history and GitHub retention controls where applicable.

### D. Retire the Terraform state backend last

The `rg-terraform-state` Resource Group and Storage Account are manually bootstrapped and not managed by either Terraform root. Keep them until the lab resource deletion and audit/retention needs are complete. If retiring them, first export any state required for audit to an access-controlled encrypted archive and confirm no workflows or Terraform users need it. Then delete the exact state Storage Account and its resource group in Azure Portal or with Azure CLI only after independently checking the active subscription and resource names. Deleting the backend destroys state versions/locks and can make remaining resources unmanaged; never use backend deletion as a way to “reset” Terraform.

Finally, re-run `az resource list` for the lab and state resource groups and review Azure Cost Management for lingering resources, storage, snapshots, or services outside Terraform.

Never delete a `.tfstate` blob manually to reset the project. Losing state can leave existing resources unmanaged or cause duplicate creation.

## Existing VM migration and key rotation

Changing an existing deployment from password login back to public-key-only authentication may force VM replacement. Review the Terraform plan. Recreating the VM installs the configured public key; removing a key from source does not revoke it from existing VMs or erase it from Azure state versions/backups, GitHub artifacts, or Git history. Rotate/revoke exposed keys and clean retained copies according to repository/storage retention policies. Never edit Terraform state by hand.

If the private key is exposed, revoke/recreate the key and replace affected VMs. Rotating a GitHub secret alone does not change the authorized key on already running VMs.

## Final checklist

- Destroy module 02 if the lab is temporary.
- Retain and protect state until the foundation is deliberately decommissioned.
- Remove temporary subscription-scope bootstrap RBAC when no longer required.
- Disable unused GitHub/Tailscale credentials and `tag:ci` access.
- Rotate exposed keys and review Git history, workflow artifacts, and Blob versions/backups before sharing the repository.
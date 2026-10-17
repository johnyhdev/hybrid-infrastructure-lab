# 08 — Limitations, security, and cleanup

## Current limitations

- This is a small learning lab, not a production architecture: no HA/SLA, autoscaling, backup/restore runbooks, centralized logging, alerting, incident response, or end-to-end monitoring.
- Defaults create one control-manager and one workload VM in one region/zone. VM maps allow more entries, but scaling, quota, routing, inventory, and failure behavior are not validated.
- Default VMs use Ubuntu 24.04 ARM64, `Standard_D2ps_v6`, zone 1. Confirm availability and quota in each subscription.
- No Public IP is provisioned. SSH administration is intended over Tailscale/private networking. Keep the administrator private key protected for emergency access; never open SSH to the Internet for debugging.
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

1. Confirm the target subscription and identify all lab resources/costs.
2. Dispatch `Terraform VM Resource Destroy` from `main` only after checking the workflow run and target. Its current review gap is described above.
3. Verify module 02 VMs, NICs, VNet, NSGs, and optional LB are gone. The workflow does not remove the resource group or `id-cm` managed identity owned by module 01.
4. Remove the identity foundation only through a separate reviewed procedure after confirming it is no longer needed. Do not delete the state backend while Terraform state must be retained or workflows may still run.
5. Check for costs from state storage, snapshots, and resources outside Terraform.

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
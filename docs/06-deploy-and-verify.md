# 06 — Run workflows, deploy, and verify

Follow this sequence. Do not approve an apply until state, Azure OIDC/RBAC, and Tailscale credentials are configured.

## Push and review checks

1. Check `git status`; ensure state, `.terraform/`, tfvars, passwords, private keys, and plan files are not committed.
2. Push a branch to your GitHub fork and open a pull request against `main`.
3. Review Ansible checks, Tailscale policy tests (if changed), Terraform plan summaries, TFLint, and Checkov results. Stop if the plan targets the wrong subscription/resource group or contains unexpected changes/replacements.
4. Confirm each workflow is using the intended GitHub Environment and succeeds in OIDC/backend authentication.
5. Merge only after review. The apply workflow finds the plan artifact and waits at the apply environment for approval. Review the plan summary, run, and target before approving.

Apply the initial Tailscale policy manually before creating VMs so the required tags and route rules are present. Later policy changes should pass the PR test and be reviewed before merge.

## Apply the identity root first

The first infrastructure PR must change `terraform/01-identity/**` so the plan workflow runs. Review, merge, and approve `terraform-identity-apply`. It should create:

- The persistent lab Resource Group.
- User Assigned Managed Identity `id-cm`.
- Azure `Reader` role assignment for the managed identity principal on the lab Resource Group.

The identity module uses a separate Blob state key, `hybrid-identity.tfstate`. It should not create VMs or network resources. If the apply fails with `roleAssignments/write`, fix the identity apply RBAC described in document 03; do not grant Owner broadly.

## Apply the VM/network root

Open a PR changing `terraform/02-vmresource/**` (or another path included in the workflow filter) and inspect the plan. After merge, approve `terraform-vmresource-apply`. The default plan creates:

- VNet `10.20.0.0/16`, automation subnet `10.20.1.0/24`, workload subnet `10.20.2.0/24`, and NSGs.
- One Ubuntu 24.04 ARM64 control-manager and one workload VM according to the VM maps.
- No Public IP.
- No Load Balancer by default (`enable_load_balancer = false`).

Terraform apply finishing does not mean cloud-init/Tailscale is ready. The Ansible deploy workflow joins Tailscale as `tag:ci`, then uses its existing OpenSSH commands to connect to the CM's Tailscale IP. Tailscale SSH and tailnet policy authorize the CI identity; no `SSH_PRIVATE_KEY` secret or `ssh-agent` step is needed. The CM runs Ansible to configure workloads over the private Azure network.

The deployment keeps the existing OpenSSH options, including `StrictHostKeyChecking=no` and `ConnectTimeout=5`. Tailscale SSH provides access authorization through tailnet identity/policy; disabling host-key checking still weakens SSH server identity verification. This is retained for compatibility with the lab automation, not recommended for sensitive production workloads.

If migrating from existing VMs provisioned with `SSH_PUBLIC_KEY`, review the plan because changing VM authentication can force replacement. Recreating a VM removes its old authorized key; deleting the public key from source does not revoke it from an existing VM or erase it from state versions, old workflow artifacts, or Git history. Do not edit Terraform state by hand.

## Verify Azure and Tailscale

```powershell
az vm list --resource-group "<LAB_RESOURCE_GROUP>" --show-details --query "[].{name:name,power:powerState,privateIp:privateIps}" --output table
az network vnet subnet list --resource-group "<LAB_RESOURCE_GROUP>" --vnet-name "<VNET_NAME>" --output table
az vm identity show --resource-group "<LAB_RESOURCE_GROUP>" --name "vm-cm-01" --output json
```

Confirm both VMs are running and private-only, the CM has `id-cm`, and no Public IP is associated. In Tailscale Admin Console → Machines, verify `vm-cm-01` is online with `tag:cm` and that route `10.20.2.0/24` is advertised and approved. Confirm the Ansible deploy workflow succeeds and inventory discovers the workload.

An administrator whose Tailscale identity is permitted by the policy can connect over the private tailnet, for example `ssh azureadmin@<CM_TAILSCALE_IP>`. This uses Tailscale SSH authorization and does not require the VM administrator private key. Keep the private key corresponding to `SSH_PUBLIC_KEY` protected as a separate VM-level emergency credential; do not place it in GitHub CI. Do not use a public IP or open SSH to the Internet. Password authentication is disabled.

## Verify Ansible services

On the workload through the CM/Ansible, confirm:

- Nginx is active on port 80 and proxies to the sample app at `127.0.0.1:8080`.
- `sample-app` is active; test through Nginx on port 80 and locally on port 8080.
- PostgreSQL packages/service are installed, but no database/schema/application integration is configured.
- Node Exporter is active on port 9100; NSG rules restrict access to the automation subnet.

Use Ansible output, `systemctl status <service>`, and `journalctl -u <service> -n 100 --no-pager` to troubleshoot. The app is not internet-facing. Re-run Ansible to test convergence; upstream package/template changes can still produce changes between runs.

## Destroy the temporary VM environment

The `Terraform VM Resource Destroy` workflow manages module 02 only. Its current implementation generates and displays a destroy plan, then executes a separate `terraform destroy -auto-approve`; that execution does **not** apply the saved plan. GitHub Environment approval occurs before the plan is generated, so it is not approval of the exact destroy diff. Treat this as a documented review gap and use only in an isolated lab after checking the workflow run/target. The identity root is separate and is not destroyed by this workflow. See [08 — Limitations and cleanup](08-limitations-and-cleanup.md).
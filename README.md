# Hybrid Infrastructure Lab

A hands-on lab for Terraform, Azure, Ansible, GitHub Actions OIDC, and Tailscale. Terraform provisions a private control-manager VM and workload VM. The control manager uses an Azure Managed Identity to join the tailnet, runs Ansible over the private network, and deploys sample services.

This is a learning lab, **not a production architecture**. Azure resources may incur charges. Review [limitations, security, and cleanup](docs/08-limitations-and-cleanup.md) before deploying.

## Start here

Read the numbered documents in `docs/` in order. They explain the manual bootstrap and how to configure your own Azure tenant, GitHub repository, and Tailscale tailnet:

1. [01 — Prerequisites and clone setup](docs/01-prerequisites-and-clone.md)
2. [02 — Bootstrap the Azure Blob state backend](docs/02-azure-state-backend.md)
3. [03 — Entra OIDC, federated credentials, and Azure RBAC](docs/03-azure-oidc-rbac.md)
4. [04 — Tailscale WIF and policy](docs/04-tailscale-wif-policy.md)
5. [05 — GitHub Environments, secrets, variables, and protection](docs/05-github-environments.md)
6. [06 — Run workflows, deploy, and verify](docs/06-deploy-and-verify.md)
7. [07 — Troubleshooting by checkpoint](docs/07-troubleshooting.md)
8. [08 — Limitations, security, and cleanup](docs/08-limitations-and-cleanup.md)

The current repository has two independent Terraform roots and state files; the numbered documents describe this current layout.

## What the lab does

- **Terraform and Azure:** `terraform/01-identity` creates the persistent lab Resource Group, User Assigned Managed Identity `id-cm`, and its Azure `Reader` role assignment. `terraform/02-vmresource` creates the VNet, automation/workload subnets, NSGs, NICs, and Ubuntu 24.04 ARM64 VMs from map variables.
- **Private management:** VMs have no Public IP. The control manager obtains a token using its Azure Managed Identity, joins Tailscale as `tag:cm`, advertises the workload subnet, and uses Azure CLI plus generated inventory to discover VMs.
- **Ansible:** applies a Linux baseline, Nginx reverse proxy, sample HTTP application, PostgreSQL packages, and Prometheus Node Exporter to workload VMs. A remediation playbook can restart services.
- **GitHub Actions:** runs Terraform plan/security checks, gated applies, Ansible checks/deployment, and Tailscale policy GitOps. Azure authentication uses OIDC rather than a client secret.
- **Tailscale:** GitHub CI joins the tailnet through OIDC and connects to the control manager using the existing OpenSSH commands over the Tailscale network. Tailscale SSH identity and policy authorize CI; no VM administrator private key is loaded into GitHub. The control manager uses a separate Terraform-generated key to connect to workload VMs.

## Architecture and deployment order

```text
Developer / GitHub PR
        |
        +--> GitHub Actions --OIDC--> Microsoft Entra ID --> Azure RBAC
        |                                  |                    |
        |                                  |                    +--> Terraform state (Azure Blob)
        |                                  +--> Terraform plan/apply
        |                                                       |
        +--> Tailscale policy GitOps ---------------------------+
                                                                |
Azure: rg-hybrid-infra-lab                                     |
  +-- id-cm (User Assigned Managed Identity)                    |
  +-- VNet 10.20.0.0/16                                        |
  |    +-- automation 10.20.1.0/24                              |
  |    |     +-- control-manager VM (tag:cm) <--- Tailscale     |
  |    +-- workload 10.20.2.0/24                                |
  |          +-- workload VM(s) <--- Ansible over private VNet  |
  +-- no Public IP / no public SSH                              |
```

Apply `01-identity` first, then `02-vmresource`. A successful VM-resource apply can trigger the Ansible deployment workflow. The Azure Blob backend must be created manually before Terraform initialization; see document 02.

## Requirements

- An Azure subscription with billing, permissions, and quota for Central India, zone 1, and the default `Standard_D2ps_v6` Ubuntu 24.04 ARM64 VM SKU. Verify current availability, pricing, and quota before applying.
- A GitHub repository with Actions enabled and permission to configure Environments, secrets, variables, and branch protection. Use a dedicated test repository where possible; do not expose privileged workflows to untrusted PR code.
- A Tailscale tailnet supporting OIDC/WIF, policy GitOps, and the required SSH access.
- Local tools: Git, Terraform CLI `>= 1.6.0`, and Azure CLI. GitHub CLI, VS Code extensions, and WSL are useful but optional. Local Python is not required for Terraform/GitHub workflows.
- An Azure Storage Account and Blob container created before Terraform initialization. The backend uses Azure AD/OIDC; CI identities need Blob data-plane permissions for state access and locking.

Document 01 covers the Windows workstation and regional checks; documents 02–05 detail backend, Azure RBAC, Tailscale, and GitHub configuration.

## VM authentication and key handling

Azure Linux VM provisioning requires an authentication mechanism. This project configures an administrator SSH **public** key and disables password authentication. Store its public half as `SSH_PUBLIC_KEY` in the VM plan, apply, and destroy GitHub Environments. Keep the matching private key protected; never commit or upload it to those Terraform environments.

The Ansible CI workflow joins Tailscale through OIDC and uses its existing OpenSSH commands to reach the CM's Tailscale IP. Tailscale SSH identity/policy authorizes CI, so no `SSH_PRIVATE_KEY` secret is needed. The workflow retains `StrictHostKeyChecking=no` and `ConnectTimeout=5` for compatibility; disabling host-key checking weakens server identity verification and is not recommended for sensitive environments.

Terraform also generates an internal CM-to-workload SSH key. Its private material is present in Terraform state and delivered to the CM through cloud-init/custom data. Terraform's `sensitive` marking redacts routine output; it does **not** encrypt state. Protect the Blob backend, state versions/backups, plans, cloud-init data, and Azure control-plane access.

## Features and known limitations

- The sample app is a small HTTP responder on loopback port 8080; Nginx proxies it on workload port 80. There is no internet-facing endpoint.
- PostgreSQL is installed but the app does not use it; no database, schema, credentials, TLS, or backups are configured.
- Node Exporter is installed, but no Prometheus server, metrics retention, or dashboard is included.
- Ansible `*_enabled` variables are declared but are not currently used to conditionally skip roles.
- The optional Load Balancer is scaffolding: workload NICs/IP configurations are not associated with its backend pool. Its frontend is private; do not enable it expecting traffic distribution.
- Defaults create one control-manager and one workload VM. Scale-out, HA, and failover are not validated.
- The lab has no HA/SLA, centralized logging, alerting, backup/restore runbooks, incident response, or production hardening review.
- VM image version is `latest`; bootstrap and configuration install upstream software.
- The control manager clones the repository using a hard-coded HTTPS URL. Private repositories need a deliberate authentication design; never embed a PAT in cloud-init.
- GitHub plan summaries/artifacts may reveal topology or configuration; restrict access and retention.
- The destroy workflow displays a destroy plan and then runs a separate `terraform destroy -auto-approve`; it does not apply the saved plan. Environment approval happens before plan generation, so it is not approval of the exact destroy diff. Use only in an isolated lab until the workflow is redesigned for separate plan review and apply approval.

See [all limitations and cleanup guidance](docs/08-limitations-and-cleanup.md) and [troubleshooting](docs/07-troubleshooting.md).

## Repository map

- `.github/workflows/` — Terraform plan/apply/destroy, Ansible checks/deploy, and Tailscale policy GitOps.
- `terraform/01-identity/` — persistent Resource Group, managed identity, and `cm_reader` role assignment.
- `terraform/02-vmresource/` — private network, VMs, NSGs, and optional private Load Balancer scaffolding.
- `bootstrap/` — control-manager and workload cloud-init.
- `ansible/` — inventory generator, playbooks, roles, and templates. Generated inventory under `ansible/inventory/generated/` is local runtime output and is ignored by Git.
- `tailscale/policy.hujson` — tags, route approval, grants, and Tailscale SSH rules.
- `docs/01-...08-...` — ordered setup, verification, troubleshooting, and cleanup instructions.

## Verification scope

The numbered guides provide setup steps based on the repository configuration, but they cannot verify your live Azure subscription, GitHub Environment protection/OIDC claims, Tailscale UI settings, quotas, or deployment. Tailscale issuer/audience values and repository-specific identifiers must be copied from your own consoles and checked against the workflow. Follow the verification checkpoints, stop on unexpected output, and review every Terraform plan in your own environment before approval.
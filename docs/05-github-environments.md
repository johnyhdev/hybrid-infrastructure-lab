# 05 — GitHub Environments, secrets, variables, and protection

Create the environments below under Repository → Settings → Environments. Names are case-sensitive and form part of OIDC subjects; do not rename them without updating federated credentials.

## Azure environments

Use the Entra app for the matching environment from document 03. Add these **secrets** to each environment:

| Environment | `AZURE_CLIENT_ID` | `AZURE_TENANT_ID` | `AZURE_SUBSCRIPTION_ID` | Additional secret | Variables |
|---|---|---|---|---|---|
| `terraform-identity-plan` | Identity plan app ID | Tenant ID | Lab subscription ID | — | — |
| `terraform-identity-apply` | Identity apply app ID | Tenant ID | Lab subscription ID | — | — |
| `terraform-vmresource-plan` | VM plan app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |
| `terraform-vmresource-apply` | VM apply app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |
| `terraform-destroy` | Destroy app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |

`SSH_PUBLIC_KEY` must contain the public half of the key pair, e.g. the complete single-line content of the `.pub` file. Never put the private key in these Terraform environments or in the repository.

## Tailscale environments

- `tailscale-ci`: create secrets `TAILSCALE_CI_CLIENT_ID` and `TAILSCALE_CI_AUDIENCE` only. No `SSH_PRIVATE_KEY` secret is required for the current CI-to-CM connection.
- `tailscale-policy`: create variables `TAILSCALE_POLICY_CLIENT_ID`, `TAILSCALE_POLICY_AUDIENCE`, and `TAILSCALE_TAILNET`.

The CI workflow joins the tailnet using the Tailscale OIDC credential, then uses its existing OpenSSH commands to connect to the CM's Tailscale IP. The VM's Tailscale SSH server and tailnet policy authorize that connection; the workflow does not need the administrator SSH private key. The `SSH_PUBLIC_KEY` remains configured on the VMs as Azure-required VM provisioning/emergency authentication, but is not the CI authentication mechanism.

The existing deployment workflow keeps its OpenSSH options, including `StrictHostKeyChecking=no` and `ConnectTimeout=5`. Tailscale SSH uses tailnet identity/policy for access; disabling host-key checking still weakens server identity verification and is retained for compatibility with this lab automation, not recommended for sensitive production workloads.

## Protect environments and `main`

- `terraform-identity-apply`, `terraform-vmresource-apply`, and `terraform-destroy`: require trusted reviewers and restrict deployment branches to `main`. Destroy is particularly sensitive.
- Plan environments should not expose Azure credentials to untrusted fork PR code. Use a private test repository or suitable restrictions.
- `tailscale-policy`: allow policy tests for PRs while limiting policy apply to `main`; required reviewers on the shared environment may also gate the PR test job.
- `tailscale-ci`: restrict deployment access and use required reviewers if every Ansible deployment should be approved.
- Protect `main` with reviewed pull requests and required status checks. Enable GitHub Actions for the repository.

GitHub Environments do not automatically inherit secrets from one another. Confirm every workflow's referenced secrets/variables are set in the exact environment. Continue with [06 — Deploy and verify](06-deploy-and-verify.md).
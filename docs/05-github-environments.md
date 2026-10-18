# 05 — GitHub Environments, secrets, variables, and protection

Create the environments below under Repository → Settings → Environments. Names are case-sensitive and form part of OIDC subjects; do not rename them without updating federated credentials.

In the GitHub repository, open **Settings → Environments → New environment**, enter one exact name from the tables below, and select **Configure environment**. Repeat for every listed environment. Inside each environment, use **Add environment secret** for secret values and **Add environment variable** for non-secret values; enter the exact uppercase key, paste its matching value, and save. Do not create repository-wide copies as a substitute: each workflow references an environment-scoped value. After setup, revisit each Environment and confirm the key names appear in the correct Secrets or Variables section (GitHub does not reveal saved secret values).

## Azure environments

Use the Entra app for the matching environment from document 03. Add these **secrets** to each environment:

| Environment | `AZURE_CLIENT_ID` | `AZURE_TENANT_ID` | `AZURE_SUBSCRIPTION_ID` | Additional secret | Variables |
|---|---|---|---|---|---|
| `terraform-identity-plan` | Identity plan app ID | Tenant ID | Lab subscription ID | — | — |
| `terraform-identity-apply` | Identity apply app ID | Tenant ID | Lab subscription ID | — | — |
| `terraform-vmresource-plan` | VM plan app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |
| `terraform-vmresource-apply` | VM apply app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |
| `terraform-destroy` | Destroy app ID | Tenant ID | Lab subscription ID | `SSH_PUBLIC_KEY` | `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` |

`SSH_PUBLIC_KEY` must contain the public half of the key pair, e.g. the complete single-line content of the `.pub` file. Never put the private key in these Terraform environments or in the repository. This is the key Azure installs during VM provisioning; the documented normal CM access path is Tailscale SSH, and this lab does not configure/verify a separate private-key recovery path.

## Tailscale environments

- `tailscale-ci`: create secrets `TAILSCALE_CI_CLIENT_ID` and `TAILSCALE_CI_AUDIENCE` only. No `SSH_PRIVATE_KEY` secret is required for the current CI-to-CM connection.
- `tailscale-policy`: create variables `TAILSCALE_POLICY_CLIENT_ID`, `TAILSCALE_POLICY_AUDIENCE`, and `TAILSCALE_TAILNET`.

The CI workflow joins the tailnet using the Tailscale OIDC credential, then uses its existing OpenSSH commands to connect to the CM's Tailscale IP. The VM's Tailscale SSH server and tailnet policy authorize that connection; the workflow does not need the administrator SSH private key. The `SSH_PUBLIC_KEY` remains configured on the VMs for Azure VM provisioning, but is not the CI authentication mechanism.

The existing deployment workflow keeps its OpenSSH options, including `StrictHostKeyChecking=no` and `ConnectTimeout=5`. Tailscale SSH uses tailnet identity/policy for access; disabling host-key checking still weakens server identity verification and is retained for compatibility with this lab automation, not recommended for sensitive production workloads.

## Protect environments and `main`

Configure protection while viewing each Environment's settings:

1. For `terraform-identity-apply`, `terraform-vmresource-apply`, and `terraform-destroy`, enable **Required reviewers**, select trusted maintainers who can approve deployments, and set **Deployment branches and tags** to selected branches with only `main` allowed. Save each environment. Destroy is especially sensitive.
2. For plan environments, remember that a job receives the Environment's secrets when it runs. Do not expose these credentials to untrusted fork pull requests. Prefer a private lab repository; otherwise configure repository/workflow restrictions and review the trust implications before enabling Actions.
3. `tailscale-policy` is shared by PR test and main apply jobs. A required reviewer on this environment may gate the PR test too. If requiring approval, test the PR workflow behavior and ensure a trusted reviewer can approve it; do not mistakenly interpret a waiting job as a failed policy test.
4. For `tailscale-ci`, restrict deployment branches to `main`. Add required reviewers if every automatic Ansible deployment must pause for approval; otherwise understand that a successful VM apply on `main` can trigger deployment without a separate approval.
5. Open **Settings → Rules → Rulesets** (or the repository's branch-protection settings), create a rule targeting `main`, require pull requests and at least one approval, dismiss stale approvals when new commits are pushed, and require the status checks that actually appear for this repository. Enable GitHub Actions under **Settings → Actions → General**.
6. To select required checks accurately, create a harmless documentation PR first and inspect the completed checks. Require the Terraform plan checks that should gate changes (for this repo they are reported as `Terraform Identity Plan` and `Terraform VM Resource Plan` when their path filters run), plus the relevant Ansible/Tailscale tests for changes they cover. Do not require a check that cannot run for the relevant path or a skipped conditional job; GitHub can otherwise leave merges blocked. Re-test the rule with a PR after saving it.

The repository's `.github/CODEOWNERS` nominates an owner for review, but a CODEOWNERS file by itself does **not** require approval. The branch rule must enable code-owner review, and the listed owner/team must have repository access. Never approve your own production-like change as a substitute for an independent reviewer.

To verify the result, open each Environment again and check its deployment branch/reviewer settings, then open the branch-rules page and confirm the active rule targets `main`. Create a test PR and confirm the expected checks appear and block merging when they fail; do not test by approving a real infrastructure apply.

GitHub Environments do not automatically inherit secrets from one another. Confirm every workflow's referenced secrets/variables are set in the exact environment. Continue with [06 — Deploy and verify](06-deploy-and-verify.md).
# 04 — Tailscale WIF and policy

The repository uses three distinct Tailscale identity flows: the Azure managed identity on the control-manager, the GitHub CI runner, and policy GitOps. Do not interchange their client IDs or audiences. Do not create long-lived Tailscale auth keys for these flows.

## Prepare and apply the initial policy

1. Open Tailscale Admin Console → Access Controls.
2. Review `tailscale/policy.hujson` and apply the initial policy manually before creating VMs so the tags and route rules are available.
3. The current policy defines `tag:cm` and `tag:ci`, auto-approves route `10.20.2.0/24`, allows `tag:ci` TCP 22/443 to the CM/workload subnet, and permits Tailscale SSH to the CM as `azureadmin` and `root`.
4. Review tag ownership, route access, and root access carefully. `tag:ci` has powerful access. If the CIDRs change, update Terraform NSGs, route approval, and grants together.

The `tailscale-policy` GitHub Environment is used by both PR tests and main-branch apply. Required reviewers on this environment may block PR tests as well; configure protection deliberately.

## GitHub policy GitOps credential

Create a GitHub Actions OpenID Connect trust credential in Tailscale:

- Issuer: `https://token.actions.githubusercontent.com`
- Subject: the exact GitHub repository/environment subject for `tailscale-policy` (see document 03 and verify current GitHub OIDC claims).
- Permissions: least privilege that permits policy read/test on PRs and policy update after merge (`policy_file` scopes as offered by current Tailscale documentation/UI).

Record the generated Client ID and Audience plus the Tailnet ID/unique ID from Tailscale Admin Console. The audience often resembles `api.tailscale.com/<CLIENT_ID>`; use the exact value Tailscale returns. These identifiers are not bearer secrets; store them as GitHub Environment Variables in document 05.

## GitHub CI credential

Create a separate GitHub OIDC credential for the `tailscale-ci` environment:

- Issuer and subject must match the GitHub repository and `tailscale-ci` environment.
- Grant machine enrollment/auth-key write only for `tag:ci`, according to the Tailscale UI.
- Record this credential's Client ID and Audience separately from policy and CM values.

## Azure managed identity credential

After the identity module creates `id-cm`, retrieve its identifiers:

```powershell
az identity show --resource-group "<LAB_RESOURCE_GROUP>" --name "<CM_IDENTITY_NAME>" --query "{tenantId:tenantId,principalId:principalId,clientId:clientId}" --output table
```

Create a Tailscale trust credential for Microsoft Entra/Azure:

- Issuer: the Microsoft Entra issuer required by Tailscale's current UI.
- Subject: the **principal ID** of the User Assigned Managed Identity `id-cm`, not its client ID.
- Audience: the value required for Azure token exchange by the Tailscale credential. Use the exact audience shown by Tailscale; never paste a bearer JWT/access token into configuration or logs.
- Permit the required enrollment scope and `tag:cm` only.

Record the Tailscale CM credential Client ID and Audience. Set them as GitHub Variables available to `terraform-vmresource-plan`, `terraform-vmresource-apply`, and `terraform-destroy`. Terraform passes them to cloud-init, where the VM obtains an Azure Managed Identity token and joins Tailscale.

## Keep the identities distinct

| Value | Purpose | GitHub storage |
|---|---|---|
| `TAILSCALE_POLICY_CLIENT_ID`, `TAILSCALE_POLICY_AUDIENCE`, `TAILSCALE_TAILNET` | Policy test and apply | Variables in `tailscale-policy` |
| `TAILSCALE_CI_CLIENT_ID`, `TAILSCALE_CI_AUDIENCE` | CI runner joins the tailnet | Secrets in `tailscale-ci` |
| `TAILSCALE_CM_CLIENT_ID`, `TAILSCALE_CM_AUDIENCE` | Control-manager VM WIF | Variables in VM plan/apply/destroy environments |
| `id-cm` principal ID | Subject in Azure-to-Tailscale trust | Not a Tailscale client ID; not a GitHub secret |

Verify that the policy test succeeds, the CM appears online with `tag:cm`, and its advertised workload route is approved. Continue with [05 — GitHub Environments](05-github-environments.md).
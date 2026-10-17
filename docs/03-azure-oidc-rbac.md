# 03 — Microsoft Entra OIDC, federated credentials, and Azure RBAC

GitHub Actions authenticates to Azure through GitHub OIDC; do not create a client secret. Use a separate Entra application/service principal for each GitHub Environment so plan and apply permissions remain distinct. The current workflows use five Azure environments.

## Identify the repository and Azure tenant

Authenticate GitHub CLI (`gh auth login`) if required, then run in PowerShell:

```powershell
$repo = "<OWNER>/<REPOSITORY>"
$repoInfo = gh api "repos/$repo" | ConvertFrom-Json
$owner = $repoInfo.owner.login
$ownerId = $repoInfo.owner.id
$repoName = $repoInfo.name
$repoId = $repoInfo.id
$tenantId = az account show --query tenantId -o tsv
$subscriptionId = az account show --query id -o tsv
```

Verify every value. Do not copy IDs from the phase draft. GitHub may issue immutable repository subjects containing owner and repository IDs. Confirm the actual OIDC `sub` format for your repository before creating credentials. For immutable subjects, the format is:

`repo:<OWNER>@<OWNER_ID>/<REPOSITORY>@<REPOSITORY_ID>:environment:<ENVIRONMENT>`

If GitHub issues a different subject format, use the exact claim GitHub issues. Subject matching is exact.

## Create five Entra applications and service principals

Create a separate app for each environment:

- `terraform-identity-plan`
- `terraform-identity-apply`
- `terraform-vmresource-plan`
- `terraform-vmresource-apply`
- `terraform-destroy`

Example (repeat with a distinct display name):

```powershell
$app = az ad app create --display-name "<APP_DISPLAY_NAME>" | ConvertFrom-Json
$appId = $app.appId
$appObjectId = $app.id
az ad sp create --id $appId
$spObjectId = az ad sp show --id $appId --query id -o tsv
```

Record the Application/Client ID (`appId`), Application Object ID (`id`), and Service Principal Object ID separately. They are different identifiers. The Application Object ID owns the federated credential; the Service Principal Object ID receives Azure RBAC assignments.

## Create a federated credential per environment

On each matching app, create a Federated Identity Credential with:

- Issuer: `https://token.actions.githubusercontent.com`
- Audience: `api://AzureADTokenExchange`
- Subject: the exact repository/owner IDs and environment name for that job.

For example, the VM plan subject ends in `:environment:terraform-vmresource-plan`. Repeat for all five environments. Use Entra Portal (App registrations → app → Certificates & secrets → Federated credentials) or `az ad app federated-credential create --id <APP_OBJECT_ID> --parameters <JSON_FILE>`. Each JSON document contains `name`, `issuer`, `subject`, `description`, and `audiences: ["api://AzureADTokenExchange"]`. Verify the credentials on every app.

Do not use a broad `ref:main` subject for jobs configured with environments. Renaming the repository, owner, or environment requires updating FIC subjects.

## Assign Azure RBAC roles

Get the relevant scopes:

```powershell
$subscriptionScope = az account show --query id -o tsv
$labRgScope = az group show --name "<LAB_RESOURCE_GROUP>" --query id -o tsv
$storageScope = az storage account show --name "<STATE_STORAGE_ACCOUNT>" --resource-group "<STATE_RESOURCE_GROUP>" --query id -o tsv
```

Every Terraform identity needs Blob data access to read/write/lease state. Assign `Storage Blob Data Contributor` to each service principal on the state Storage Account or container. This includes plan jobs because the AzureRM backend uses blob leases:

```powershell
az role assignment create --assignee-object-id <SP_OBJECT_ID> --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope $storageScope
```

Suggested management-plane permissions:

| GitHub environment | Azure resource scope and role | Purpose |
|---|---|---|
| `terraform-identity-plan` | `Reader` at subscription scope | Initial plan may inspect whether the lab resource group and identity exist. |
| `terraform-identity-apply` | `Contributor` plus `User Access Administrator` (or suitably conditioned `Role Based Access Control Administrator`) at subscription scope for first bootstrap | Creates the resource group, managed identity, and `Reader` role assignment for `id-cm`. Contributor alone cannot create role assignments; the target group does not exist yet. |
| `terraform-vmresource-plan` | `Reader` on the lab resource group | Reads the resource group and identity and creates plans. |
| `terraform-vmresource-apply` | `Contributor` on the lab resource group | Creates networking, NSGs, NICs, and VMs. |
| `terraform-destroy` | `Contributor` on the lab resource group | Deletes resources managed by module 02 only. |

Use a dedicated lab subscription for initial identity bootstrap. After successful setup, remove or reduce subscription-scoped bootstrap privileges if they are no longer needed. Production designs should use narrower custom roles/scopes and separate identity and workload resource groups. Do not grant subscription-wide Owner for convenience.

Example assignment (repeat with the appropriate app and scope):

```powershell
az role assignment create `
  --assignee-object-id <SP_OBJECT_ID> `
  --assignee-principal-type ServicePrincipal `
  --role "Reader" `
  --scope $labRgScope
```

The `terraform/01-identity` module also creates `azurerm_role_assignment.cm_reader`: it assigns Azure `Reader` on the lab resource group to the **managed identity principal ID** of `id-cm`. This runtime permission lets the control-manager inventory process read Azure VM metadata; it is not a GitHub workflow permission. The identity apply principal must be allowed to create this role assignment.

Azure RBAC propagation can take several minutes. Blob data roles are distinct from management-plane `Reader`/`Contributor` roles.

## Checkpoint

- Five apps/service principals and five FICs exist with correct issuer, audience, and environment-specific subjects.
- Each GitHub environment uses the client ID of its corresponding app.
- Each app has Blob data access for the backend.
- Resource roles/scopes match the table; identity apply can create the bootstrap Resource Group and `cm_reader` assignment.

Continue with [04 — Tailscale WIF and policy](04-tailscale-wif-policy.md).
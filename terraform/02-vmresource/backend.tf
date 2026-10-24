terraform {
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true

    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sthybridlab202610230913"
    container_name       = "tfstate"
    key                  = "hybrid-vmresource.tfstate"
  }
}

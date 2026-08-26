terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sthybridlab260826"
    container_name       = "tfstate"
    key                  = "hybrid-infrastructure.tfstate"
  }
}

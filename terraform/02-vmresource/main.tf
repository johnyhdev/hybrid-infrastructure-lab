data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_user_assigned_identity" "cm" {
  name                = var.managed_identity_name
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "cm_reader" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.cm.principal_id
}
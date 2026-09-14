resource "azurerm_user_assigned_identity" "awx" {
  name                = "id-awx"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    role       = "awx"
    managed_by = "terraform"
  }

  # Khóa bảo vệ: Ngăn chặn Terraform xóa Identity này trong mọi trường hợp
  lifecycle {
    prevent_destroy = true
  }
}

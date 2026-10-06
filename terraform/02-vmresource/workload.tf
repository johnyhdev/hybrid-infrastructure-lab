resource "azurerm_network_interface" "workload" {
  for_each = var.workload_vms

  name                = "nic-${each.key}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 1. Quản lý việc trigger rebuild khi workload-cloud-init.yaml thay đổi
resource "terraform_data" "workload_cloud_init" {
  for_each = var.workload_vms

  input = base64encode(
    templatefile("${path.module}/../../bootstrap/workload-cloud-init.yaml", {
      hostname            = each.key
      internal_public_key = tls_private_key.internal_lab_key.public_key_openssh
    })
  )
}

resource "azurerm_linux_virtual_machine" "workload" {
  for_each = var.workload_vms

  name                = each.key
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  size = each.value.size
  zone = each.value.zone

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.workload[each.key].id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # 2. Lấy dữ liệu Base64 từ terraform_data
  custom_data = terraform_data.workload_cloud_init[each.key].output

  # 3. Tự động thay thế (recreate) VM khi cloud-init thay đổi
  lifecycle {
    replace_triggered_by = [
      terraform_data.workload_cloud_init[each.key]
    ]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server-arm64"
    version   = "latest"
  }

  tags = {
    role        = "workload"
    environment = "lab"
    managed_by  = "terraform"
  }
}
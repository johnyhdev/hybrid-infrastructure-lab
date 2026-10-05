resource "azurerm_network_interface" "cm" {
  for_each = var.control_vms

  name                = "nic-${each.key}"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.automation.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "tls_private_key" "internal_lab_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 1. Tạo resource terraform_data để theo dõi thay đổi của cloud-init template
# Dùng hàm sensitive() bọc nội dung templatefile lại
resource "terraform_data" "cm_cloud_init" {
  for_each = var.control_vms

  input = sensitive(templatefile("${path.module}/../../bootstrap/cm-cloud-init.yaml", {
    internal_private_key   = tls_private_key.internal_lab_key.private_key_pem
    internal_public_key    = tls_private_key.internal_lab_key.public_key_openssh
    tailscale_cm_client_id = var.tailscale_cm_client_id
    tailscale_cm_audience  = var.tailscale_cm_audience
    hostname               = each.key
    workload_subnet_cidr   = azurerm_subnet.workload.address_prefixes[0]
  }))
}

resource "azurerm_linux_virtual_machine" "cm" {
  for_each = var.control_vms

  name                = each.key
  resource_group_name = data.azurerm_resource_group.main.name
  location            = data.azurerm_resource_group.main.location

  size = each.value.size
  zone = each.value.zone

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.cm[each.key].id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  # 2. Lấy base64 từ output output của terraform_data
  custom_data = base64encode(terraform_data.cm_cloud_init[each.key].output)

  # 3. Tham chiếu trực tiếp đến resource terraform_data (Hợp lệ 100% với replace_triggered_by)
  lifecycle {
    replace_triggered_by = [
      terraform_data.cm_cloud_init[each.key]
    ]
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type = "UserAssigned"

    identity_ids = [
      data.azurerm_user_assigned_identity.cm.id
    ]
  }

  tags = {
    role        = "control-manager"
    environment = "lab"
    managed_by  = "terraform"
  }
}
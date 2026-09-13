resource "azurerm_subnet" "automation" {
  name                 = var.automation_subnet_name
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.20.2.0/24"]
}

resource "azurerm_network_security_group" "awx" {
  name                = "nsg-vm-awx"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet_network_security_group_association" "automation" {
  subnet_id                 = azurerm_subnet.automation.id
  network_security_group_id = azurerm_network_security_group.awx.id
}

resource "azurerm_network_interface" "awx" {
  name                = "nic-vm-awx"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.automation.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "awx" {
  name                = "vm-awx"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_D2ls_v6"
  zone                = "1"

  admin_username = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.awx.id
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  custom_data = base64encode(
    templatefile("${path.module}/../bootstrap/awx-cloud-init.yaml", {
      tailscale_client_id = var.tailscale_client_id
      tailscale_audience  = var.tailscale_audience
    })
  )




  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "rhel"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  tags = {
    role        = "awx"
    environment = "lab"
    managed_by  = "terraform"
  }

  identity {
    type = "UserAssigned"

    identity_ids = [
      azurerm_user_assigned_identity.awx.id
    ]
  }

}

output "resource_group_name" {
  description = "Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.main.name
}

output "subnets" {
  description = "Available subnets"
  value = {
    workload   = azurerm_subnet.workload.name
    automation = azurerm_subnet.automation.name
  }
}

output "awx_node" {
  description = "AWX control node information"
  value = {
    name                          = azurerm_linux_virtual_machine.awx.name
    private_ip                    = azurerm_network_interface.awx.private_ip_address
    managed_identity_id           = azurerm_user_assigned_identity.awx.id
    managed_identity_principal_id = azurerm_user_assigned_identity.awx.principal_id
    subnet_id                     = azurerm_subnet.automation.id
  }
}

output "workload_vms" {
  description = "All workload VMs"
  value = {
    (azurerm_linux_virtual_machine.main.name) = {
      private_ip = azurerm_network_interface.vm.private_ip_address
      subnet     = azurerm_subnet.workload.name
      nic_id     = azurerm_network_interface.vm.id
    }
  }
}

output "all_private_ips" {
  description = "Private IPs of infrastructure VMs"
  value = {
    awx_control   = azurerm_network_interface.awx.private_ip_address
    workload_main = azurerm_network_interface.vm.private_ip_address
  }
}

output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "vm_private_ip" {
  value = azurerm_network_interface.vm.private_ip_address
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "subnet_name" {
  value = azurerm_subnet.management.name
}
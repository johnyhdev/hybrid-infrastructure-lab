output "resource_group_name" {
  value = data.azurerm_resource_group.main.name
}

output "vnet_name" {
  value = azurerm_virtual_network.main.name
}

output "control_vm_private_ips" {
  value = {
    for name, nic in azurerm_network_interface.cm :
    name => nic.private_ip_address
  }
}

output "workload_vm_private_ips" {
  value = {
    for name, nic in azurerm_network_interface.workload :
    name => nic.private_ip_address
  }
}

output "control_vm_names" {
  value = keys(var.control_vms)
}

output "workload_vm_names" {
  value = keys(var.workload_vms)
}
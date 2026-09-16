variable "location" {
  description = "Azure region"
  type        = string
  default     = "Central India"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-hybrid-infra-lab"
}

variable "vnet_name" {
  description = "Virtual network name"
  type        = string
  default     = "vnet-hybrid-infra"

}

#VM RHEL
variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for initial VM provisioning"
  type        = string
  sensitive   = true
}

variable "tailscale_client_id" {
  description = "Tailscale federated identity client ID for the AWX VM"
  type        = string
  default     = "TNyex2DCUG11CNTRL-kTgsair2Do11CNTRL"
}

variable "tailscale_audience" {
  description = "Tailscale federated identity audience for the AWX VM"
  type        = string
  default     = "fb60f99c-7a34-4190-8149-302f77469936"
}


# Phase 6 - Config variables
variable "automation_subnet_name" {
  description = "Automation Subnet name"
  type        = string
  default     = "snet-automation"
}

variable "workload_subnet_name" {
  description = "Workload Subnet name"
  type        = string
  default     = "snet-workload"
}

variable "awx_vms" {
  type = map(object({
    size = string
    zone = string
  }))


  default = {
    "vm-awx-01" = {
      size = "Standard_D2ls_v6"
      zone = "1"
    }
  }
}

variable "workload_vms" {
  type = map(object({
    size = string
    zone = string
  }))

  default = {
    "vm-workload-01" = {
      size = "Standard_D2ls_v6"
      zone = "1"
    }
  }
}

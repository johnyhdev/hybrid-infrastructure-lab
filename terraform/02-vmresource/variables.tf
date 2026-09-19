variable "resource_group_name" {
  description = "Persistent lab resource group"
  type        = string
  default     = "rg-hybrid-infra-lab"
}

variable "managed_identity_name" {
  description = "Control Manager managed identity"
  type        = string
  default     = "id-cm"
}

variable "vnet_name" {
  description = "Main virtual network"
  type        = string
  default     = "vnet-hybrid-infra"
}

variable "automation_subnet_name" {
  description = "Control Manager subnet"
  type        = string
  default     = "snet-automation"
}

variable "workload_subnet_name" {
  description = "Workload subnet"
  type        = string
  default     = "snet-workload"
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

variable "control_vms" {
  description = "Control Manager VM definitions"

  type = map(object({
    size = string
    zone = string
  }))

  default = {
    "vm-cm-01" = {
      size = "Standard_D2ls_v6"
      zone = "1"
    }
  }
}

variable "tailscale_cm_client_id" {
  description = "Tailscale WIF client ID for CM VMs"
  type        = string
  default     = "TNyex2DCUG11CNTRL-kTgsair2Do11CNTRL"
}

variable "tailscale_cm_audience" {
  description = "Tailscale WIF audience for CM VMs"
  type        = string
  default     = "fb60f99c-7a34-4190-8149-302f77469936"
}

variable "workload_vms" {
  description = "Workload VM definitions"

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

variable "enable_load_balancer" {
  description = "Enable Azure Load Balancer for workload VMs"
  type        = bool
  default     = false
}
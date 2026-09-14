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

variable "subnet_name" {
  description = "Subnet name"
  type        = string
  default     = "snet-management"
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

# Phase 6 - Config variables
variable "automation_subnet_name" {
  description = "Automation Subnet name"
  type        = string
  default     = "snet-automation"
}

variable "tailscale_client_id" {
  description = "Tailscale federated identity client ID for the AWX VM"
  type        = string
  default     = "TNyex2DCUG11CNTRL-kFo6dvm88Q11CNTRL"
}

variable "tailscale_audience" {
  description = "Tailscale federated identity audience for the AWX VM"
  type        = string
  default     = "api.tailscale.com/TNyex2DCUG11CNTRL-kFo6dvm88Q11CNTRL"
}

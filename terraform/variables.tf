variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure deployment region"
  type        = string
  default     = "denmarkeast"
}

variable "resource_group_name" {
  description = "Project resource group"
  type        = string
  default     = "rg-nssa320-g3"
}

variable "admin_username" {
  description = "Linux VM administrator"
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for the Azure VMs"
  type        = string
}

variable "allowed_admin_cidrs" {
  description = "Authorized external management networks"
  type        = list(string)
}

variable "vnet_cidr" {
  type    = string
  default = "10.30.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.30.1.0/24"
}

variable "monitor_private_ip" {
  type    = string
  default = "10.30.1.10"
}

variable "client_private_ip" {
  type    = string
  default = "10.30.1.20"
}

variable "monitor_vm_size" {
  type    = string
  default = "Standard_D2ls_v5"
}

variable "client_vm_size" {
  type    = string
  default = "Standard_D2ls_v5"
}

variable "monitor_disk_size" {
  type    = number
  default = 64
}

variable "client_disk_size" {
  type    = number
  default = 32
}

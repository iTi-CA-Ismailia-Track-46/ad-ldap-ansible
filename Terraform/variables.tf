variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "servers-ad"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "Switzerland north"
}

variable "admin_password" {
  description = "Admin password for all VMs (set via TF_VAR_admin_password environment variable)"
  type        = string
  sensitive   = true
}

variable "linux_admin_username" {
  description = "Admin username for Linux VMs"
  type        = string
  default     = "ansible"
}

variable "windows_admin_username" {
  description = "Admin username for Windows VM"
  type        = string
  default     = "ansible"
}

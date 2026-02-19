output "windows_server_public_ip" {
  description = "Public IP address of the Windows Server VM"
  value       = azurerm_public_ip.windows_pip.ip_address
}

output "redhat_public_ip" {
  description = "Public IP address of the Red Hat Linux VM"
  value       = azurerm_public_ip.redhat_pip.ip_address
}

output "ubuntu_public_ip" {
  description = "Public IP address of the Ubuntu Linux VM"
  value       = azurerm_public_ip.ubuntu_pip.ip_address
}

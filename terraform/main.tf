###############################################################################
# Resource Group
###############################################################################
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

###############################################################################
# Virtual Network & Subnet
###############################################################################
resource "azurerm_virtual_network" "vnet" {
  name                = "main-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "main-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

###############################################################################
# Network Security Group – Allow SSH + RDP
###############################################################################
resource "azurerm_network_security_group" "nsg" {
  name                = "main-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-in-all"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-out-all"
    priority                   = 1002
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

###############################################################################
# Public IPs (Static)
###############################################################################
resource "azurerm_public_ip" "windows_pip" {
  name                = "windows-server-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "redhat_pip" {
  name                = "redhat-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "ubuntu_pip" {
  name                = "ubuntu-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

###############################################################################
# Network Interfaces
###############################################################################
resource "azurerm_network_interface" "windows_nic" {
  name                = "windows-server-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.6"
    public_ip_address_id          = azurerm_public_ip.windows_pip.id
  }
}

resource "azurerm_network_interface" "redhat_nic" {
  name                = "redhat-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.redhat_pip.id
  }
}

resource "azurerm_network_interface" "ubuntu_nic" {
  name                = "ubuntu-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu_pip.id
  }
}

###############################################################################
# Cloud-Init – 1 GB Swap for Linux VMs
###############################################################################
locals {
  linux_cloud_init = <<-CLOUD_INIT
    #cloud-config
    swap:
      filename: /swapfile
      size: 1073741824
      maxsize: 1073741824
    runcmd:
      - swapon --show
  CLOUD_INIT
}

###############################################################################
# VM 1 – Windows Server (2 vCPU / 4 GiB RAM)
###############################################################################
resource "azurerm_windows_virtual_machine" "windows_server" {
  name                = "windows-server"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = var.windows_admin_username
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.windows_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

###############################################################################
# VM Extension – Configure WinRM for Ansible on Windows Server
###############################################################################
resource "azurerm_virtual_machine_extension" "winrm_setup" {
  name                 = "winrm-setup"
  virtual_machine_id   = azurerm_windows_virtual_machine.windows_server.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $url ='https://raw.githubusercontent.com/ansible/ansible-documentation/devel/examples/scripts/ConfigureRemotingForAnsible.ps1'; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($url)); winrm set winrm/config/service/Auth '@{Basic=\\\"true\\\"}'; winrm set winrm/config/service '@{AllowUnencrypted=\\\"true\\\"}'\""
    }
  SETTINGS
}

###############################################################################
# VM 2 – Red Hat Linux (1 vCPU / 0.5 GiB RAM + 1 GB Swap)
###############################################################################
resource "azurerm_linux_virtual_machine" "redhat" {
  name                            = "redhat-linux"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B1ls"
  admin_username                  = var.linux_admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.redhat_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9-lvm-gen2"
    version   = "latest"
  }

  custom_data = base64encode(local.linux_cloud_init)
}

###############################################################################
# VM 3 – Ubuntu Linux (1 vCPU / 0.5 GiB RAM + 1 GB Swap)
###############################################################################
resource "azurerm_linux_virtual_machine" "ubuntu" {
  name                            = "ubuntu-linux"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  size                            = "Standard_B1ls"
  admin_username                  = var.linux_admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.ubuntu_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(local.linux_cloud_init)
}

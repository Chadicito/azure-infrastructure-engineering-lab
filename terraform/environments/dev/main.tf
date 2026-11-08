terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  resource_provider_registrations = "none"

  features {}
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-az-infra-lab-dev"
  location = "East US 2"

  tags = {
    Environment = "Development"
    Project     = "Azure-Infrastructure-Lab"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-lab-dev"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Project     = "Azure-Infrastructure-Lab"
  }
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web-dev"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-mgmt-dev"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-dev"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  security_rule {
    name                       = "Allow-SSH-Admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${var.admin_ip}/32"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Project     = "Azure-Infrastructure-Lab"
  }
}

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}


# Public IP
resource "azurerm_public_ip" "web" {
  name                = "pip-web-dev"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Project     = "Azure-Infrastructure-Lab"
  }
}

# Network Interface
resource "azurerm_network_interface" "web" {
  name                = "nic-web-dev"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "ipconfig-web"
    subnet_id                     = azurerm_subnet.web.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web.id
  }
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "web" {
  name                = "vm-web-dev"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  size                = "Standard_B1ms"

  admin_username                  = "azureadmin"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.web.id
  ]

  admin_ssh_key {
    username   = "azureadmin"
    public_key = file("C:/Users/Teo/.ssh/azure-lab-key.pub")
  }

  os_disk {
    name                 = "osdisk-web-dev"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  tags = {
    Environment = "Development"
    ManagedBy   = "Terraform"
    Project     = "Azure-Infrastructure-Lab"
  }
}

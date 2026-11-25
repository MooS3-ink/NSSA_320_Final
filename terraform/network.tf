resource "azurerm_resource_group" "project" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    Project = "NSSA320"
    Group   = "3"
  }
}

resource "azurerm_virtual_network" "project" {
  name                = "g3-vnet"
  location            = azurerm_resource_group.project.location
  resource_group_name = azurerm_resource_group.project.name
  address_space       = [var.vnet_cidr]
}

resource "azurerm_subnet" "project" {
  name                            = "g3-subnet"
  resource_group_name             = azurerm_resource_group.project.name
  virtual_network_name            = azurerm_virtual_network.project.name
  address_prefixes                = [var.subnet_cidr]
  default_outbound_access_enabled = true
}

resource "azurerm_public_ip" "monitor" {
  name                = "g3-monitor-pip"
  location            = azurerm_resource_group.project.location
  resource_group_name = azurerm_resource_group.project.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "project" {
  name                = "g3-nsg"
  location            = azurerm_resource_group.project.location
  resource_group_name = azurerm_resource_group.project.name

  security_rule {
    name                       = "Allow-External-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.allowed_admin_cidrs
    destination_address_prefix = var.monitor_private_ip
  }

  security_rule {
    name                       = "Allow-Grafana"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefixes    = var.allowed_admin_cidrs
    destination_address_prefix = var.monitor_private_ip
  }

  security_rule {
    name                       = "Allow-Internal-SSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.monitor_private_ip
    destination_address_prefix = var.client_private_ip
  }

  security_rule {
    name                       = "Allow-Node-Exporter"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9100"
    source_address_prefix      = var.monitor_private_ip
    destination_address_prefix = var.client_private_ip
  }

  security_rule {
    name                       = "Deny-Other-Inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "project" {
  subnet_id                 = azurerm_subnet.project.id
  network_security_group_id = azurerm_network_security_group.project.id
}

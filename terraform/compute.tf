locals {
  vms = {
    monitor = {
      name       = "g3-monitor"
      size       = var.monitor_vm_size
      private_ip = var.monitor_private_ip
      disk_size  = var.monitor_disk_size
    }

    client = {
      name       = "g3-client"
      size       = var.client_vm_size
      private_ip = var.client_private_ip
      disk_size  = var.client_disk_size
    }
  }
}

resource "azurerm_network_interface" "vm" {
  for_each = local.vms

  name                = "${each.value.name}-nic"
  location            = azurerm_resource_group.project.location
  resource_group_name = azurerm_resource_group.project.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.project.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value.private_ip

    public_ip_address_id = each.key == "monitor" ? azurerm_public_ip.monitor.id : null
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  for_each = local.vms

  name                = each.value.name
  computer_name       = each.value.name
  resource_group_name = azurerm_resource_group.project.name
  location            = azurerm_resource_group.project.location
  size                = each.value.size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm[each.key].id
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    name                 = "${each.value.name}-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = each.value.disk_size
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.project
  ]

  tags = {
    Project = "NSSA320"
    Group   = "3"
    Role    = each.key
  }
}

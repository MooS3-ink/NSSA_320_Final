output "monitor_public_ip" {
  description = "Public IP of the monitoring server"
  value       = azurerm_public_ip.monitor.ip_address
}

output "monitor_private_ip" {
  value = azurerm_network_interface.vm["monitor"].private_ip_address
}

output "client_private_ip" {
  value = azurerm_network_interface.vm["client"].private_ip_address
}

output "resource_group_name" {
  value = azurerm_resource_group.project.name
}

output "admin_username" {
  value = var.admin_username
}

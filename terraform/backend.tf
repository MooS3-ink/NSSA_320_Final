terraform {
  backend "azurerm" {
    resource_group_name  = "rg-nssa320-g3-tfstate"
    storage_account_name = "nssa320g3tfstate89c56c"
    container_name       = "tfstate"
    key                  = "group3.tfstate"
    use_azuread_auth     = true
    use_cli              = true
  }
}

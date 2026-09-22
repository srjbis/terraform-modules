module "network" {
  source = "../network"

  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.network.address_space
  subnet_prefix       = var.network.subnet_prefix
  subnet_name         = var.network.subnet_name
  tags                = var.tags
}

# Identity and network authorization must exist before AKS joins the subnet.
resource "azurerm_user_assigned_identity" "this" {
  name                = "${var.name}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "network" {
  scope                            = module.network.id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.this.principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

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
  count               = var.identity_type == "UserAssigned" ? 1 : 0
  name                = "${var.name}-identity"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_role_assignment" "network" {
  count                            = var.identity_type == "UserAssigned" ? 1 : 0
  scope                            = module.network.id
  role_definition_name             = "Network Contributor"
  principal_id                     = azurerm_user_assigned_identity.this[0].principal_id
  principal_type                   = "ServicePrincipal"
  skip_service_principal_aad_check = true
}

# System-assigned principal IDs are available only after the cluster exists.
resource "azurerm_role_assignment" "system_network" {
  count                = var.identity_type == "SystemAssigned" ? 1 : 0
  scope                = module.network.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.this.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "private_dns" {
  count                = var.api_access.private_cluster_enabled && !contains(["System", "None"], var.private_dns_zone_id) ? 1 : 0
  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.this[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_public_ip" "nat" {
  count               = var.network_profile.outbound_type == "userAssignedNATGateway" ? 1 : 0
  name                = "${var.name}-nat-ip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "this" {
  count               = var.network_profile.outbound_type == "userAssignedNATGateway" ? 1 : 0
  name                = "${var.name}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count                = var.network_profile.outbound_type == "userAssignedNATGateway" ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "this" {
  count          = var.network_profile.outbound_type == "userAssignedNATGateway" ? 1 : 0
  subnet_id      = module.network.subnet_id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
  depends_on     = [azurerm_nat_gateway_public_ip_association.this]
}

moved {
  from = azurerm_user_assigned_identity.this
  to   = azurerm_user_assigned_identity.this[0]
}

moved {
  from = azurerm_role_assignment.network
  to   = azurerm_role_assignment.network[0]
}

mock_provider "azurerm" {}

variables {
  name                   = "aks-test"
  resource_group_name    = "rg-test"
  location               = "eastus2"
  dns_prefix             = "aks-test"
  admin_group_object_ids = ["11111111-1111-1111-1111-111111111111"]
}

run "invalid_name" {
  command = plan
  variables {
    name = "-bad"
  }
  expect_failures = [var.name]
}

run "long_name" {
  command = plan
  variables {
    name = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
  expect_failures = [var.name]
}

run "invalid_resource_group" {
  command = plan
  variables {
    resource_group_name = "bad."
  }
  expect_failures = [var.resource_group_name]
}

run "invalid_location" {
  command = plan
  variables {
    location = "East US"
  }
  expect_failures = [var.location]
}

run "invalid_dns" {
  command = plan
  variables {
    dns_prefix = "bad_prefix"
  }
  expect_failures = [var.dns_prefix]
}

run "long_dns" {
  command = plan
  variables {
    dns_prefix = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }
  expect_failures = [var.dns_prefix]
}

run "invalid_version" {
  command = plan
  variables {
    kubernetes_version = "latest"
  }
  expect_failures = [var.kubernetes_version]
}

run "unsupported_sku" {
  command = plan
  variables {
    sku_tier = "Premium"
  }
  expect_failures = [var.sku_tier]
}

run "empty_admins" {
  command = plan
  variables {
    admin_group_object_ids = []
  }
  expect_failures = [var.admin_group_object_ids]
}

run "invalid_admin" {
  command = plan
  variables {
    admin_group_object_ids = ["not-a-uuid"]
  }
  expect_failures = [var.admin_group_object_ids]
}

run "null_admin" {
  command = plan
  variables {
    admin_group_object_ids = [null]
  }
  expect_failures = [var.admin_group_object_ids]
}

run "public_without_allowlist" {
  command = plan
  variables {
    api_access = { private_cluster_enabled = false }
  }
  expect_failures = [var.api_access]
}

run "public_open_to_world" {
  command = plan
  variables {
    api_access = { private_cluster_enabled = false, authorized_ip_ranges = ["0.0.0.0/0"] }
  }
  expect_failures = [var.api_access]
}

run "public_bad_cidr" {
  command = plan
  variables {
    api_access = { private_cluster_enabled = false, authorized_ip_ranges = ["300.0.0.1/32"] }
  }
  expect_failures = [var.api_access]
}

run "public_ipv6" {
  command = plan
  variables {
    api_access = { private_cluster_enabled = false, authorized_ip_ranges = ["2001:db8::/32"] }
  }
  expect_failures = [var.api_access]
}

run "private_with_allowlist" {
  command = plan
  variables {
    api_access = { authorized_ip_ranges = ["203.0.113.0/24"] }
  }
  expect_failures = [var.api_access]
}

run "invalid_pool_name" {
  command = plan
  variables {
    system_node_pool = { name = "Bad-Pool" }
  }
  expect_failures = [var.system_node_pool]
}

run "reserved_pool_name" {
  command = plan
  variables {
    system_node_pool = { name = "rotation" }
  }
  expect_failures = [var.system_node_pool]
}

run "invalid_vm_size" {
  command = plan
  variables {
    system_node_pool = { vm_size = "" }
  }
  expect_failures = [var.system_node_pool]
}

run "zero_minimum" {
  command = plan
  variables {
    system_node_pool = { min_count = 0 }
  }
  expect_failures = [var.system_node_pool]
}

run "inverted_bounds" {
  command = plan
  variables {
    system_node_pool = { min_count = 6, max_count = 5 }
  }
  expect_failures = [var.system_node_pool]
}

run "fractional_minimum" {
  command = plan
  variables {
    system_node_pool = { min_count = 1.5 }
  }
  expect_failures = [var.system_node_pool]
}

run "fractional_maximum" {
  command = plan
  variables {
    system_node_pool = { max_count = 5.5 }
  }
  expect_failures = [var.system_node_pool]
}

run "excessive_maximum" {
  command = plan
  variables {
    system_node_pool = { max_count = 1001 }
  }
  expect_failures = [var.system_node_pool]
}

run "invalid_zone" {
  command = plan
  variables {
    system_node_pool = { zones = ["4"] }
  }
  expect_failures = [var.system_node_pool]
}

run "null_zone" {
  command = plan
  variables {
    system_node_pool = { zones = [null] }
  }
  expect_failures = [var.system_node_pool]
}

run "empty_tag_key" {
  command = plan
  variables {
    tags = { "" = "bad" }
  }
  expect_failures = [var.tags]
}

run "invalid_tag_key" {
  command = plan
  variables {
    tags = { "bad/key" = "bad" }
  }
  expect_failures = [var.tags]
}

run "null_tag_value" {
  command = plan
  variables {
    tags = { environment = null }
  }
  expect_failures = [var.tags]
}

run "long_tag_value" {
  command = plan
  variables {
    tags = { environment = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }
  }
  expect_failures = [var.tags]
}

run "too_many_tags" {
  command = plan
  variables {
    tags = { for i in range(51) : "key${i}" => "value" }
  }
  expect_failures = [var.tags]
}

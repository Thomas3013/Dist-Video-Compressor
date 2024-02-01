resource "random_pet" "name_prefix" {
  prefix = var.name_prefix
  length = 1
}

resource "azurerm_resource_group" "default" {
  name     = random_pet.name_prefix.id
  location = var.location
}

resource "azurerm_virtual_network" "default" {
  name                = "${random_pet.name_prefix.id}-vnet"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_network_security_group" "default" {
  name                = "${random_pet.name_prefix.id}-nsg"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet" "default" {
  name                 = "${random_pet.name_prefix.id}-subnet"
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name  = azurerm_resource_group.default.name
  address_prefixes     = ["10.0.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "default" {
  subnet_id                 = azurerm_subnet.default.id
  network_security_group_id = azurerm_network_security_group.default.id
}

resource "azurerm_private_dns_zone" "default" {
  name                = "${random_pet.name_prefix.id}-pdz.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.default.name

  depends_on = [azurerm_subnet_network_security_group_association.default]
}

resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "${random_pet.name_prefix.id}-pdzvnetlink.com"
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  virtual_network_id    = azurerm_virtual_network.default.id
  resource_group_name   = azurerm_resource_group.default.name
}

resource "random_password" "pass" {
  length = 20
}

resource "azurerm_postgresql_flexible_server" "default" {
  name                   = "${random_pet.name_prefix.id}-server"
  resource_group_name    = azurerm_resource_group.default.name
  location               = azurerm_resource_group.default.location
  version                = "13"
  delegated_subnet_id    = azurerm_subnet.default.id
  private_dns_zone_id    = azurerm_private_dns_zone.default.id
  administrator_login    = "adminTerraform"
  administrator_password = random_password.pass.result
  zone                   = "1"
  storage_mb             = 32768
  sku_name               = "GP_Standard_D2s_v3"
  backup_retention_days  = 7

  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}

//virtual machine

resource "tls_private_key" "linux_vm_key" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "local_file" "linux_key" {
  filename = "linuxkey.pem"

  content = tls_private_key.linux_vm_key
}

resource "azurerm_subnet" "vm-subnet" {
  name = "vm-subnet"
  address_prefixes = ["10.0.2.0/24"]
  virtual_network_name = azurerm_virtual_network.default.name
  resource_group_name = azurerm_resource_group.default.name
}

data "template_file" "linux-vm-cloud-init" {
  template = file(startup.sh)
}

resource "azurerm_network_interface" "linux-vm-nic" {
  depends_on = [ azurerm_resource_group.default ]
  name = "linux-vm-nic"
  location = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name  

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "random_password" "linux-vm-password" {
  length           = 16
  min_upper        = 2
  min_lower        = 2
  min_special      = 2
  numeric           = true
  special          = true
  override_special = "!@#$%&"
}

resource "azurerm_linux_virtual_machine" "linux-vm" {
  depends_on = [ azurerm_network_interface.linux-vm-nic ]
  location = azurerm_resource_group.location
  resource_group_name = azurerm_resource_group.name
  name = "linux-vm"
  network_interface_ids = [ azurerm_network_interface.linux-vm-nic.id ]
  size = var.linux_vm_size

source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "20.04.202209200"
 }

  os_disk {
    name                 = "linux-vm-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  computer_name  = "linux-vm"
  admin_username = var.linux_admin_username
  admin_password = random_password.linux-vm-password.result
  custom_data    = base64encode(data.template_file.linux-vm-cloud-init.rendered)
  disable_password_authentication = false
  
}

module "run_command" {
  source = "innovationnorway/vm-run-command/azurerm"  
  resource_group_name = azurerm_resource_group.default.name
  virtual_machine_name = azurerm_linux_virtual_machine.linux-vm.name
  os_type = "linux"

  command = "sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
}


module "run_command" {
  source = "innovationnorway/vm-run-command/azurerm"  
  resource_group_name = azurerm_resource_group.default.name
  virtual_machine_name = azurerm_linux_virtual_machine.linux-vm.name
  os_type = "linux"

  command = "wget https://raw.githubusercontent.com/Thomas3013/Dist-Video-Compressor/main/compose.yaml >> compose.yaml"
}

module "run_command" {
  source = "innovationnorway/vm-run-command/azurerm"  
  resource_group_name = azurerm_resource_group.default.name
  virtual_machine_name = azurerm_linux_virtual_machine.linux-vm.name
  os_type = "linux"

  command = "sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"
}


resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "compressor_cluster"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  dns_prefix          = "compressor_cluster"

  default_node_pool {
    name       = "default"
    node_count = "3"
    vm_size    = "standard_d2_v2"
  }
  identity {
    type = "SystemAssigned"
  }
  addon_profile {
    http_application_routing {
      enabled = true
    }
  }
}
















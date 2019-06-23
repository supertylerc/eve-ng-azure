variable "region" {}
variable "subscription_id" {}
variable "client_id" {}
variable "client_certificate_path" {}
variable "client_certificate_password" {}
variable "tenant_id" {}
variable "disk_size" {}
variable "ssh_pubkey" {}
variable "vm_size" {}
variable "vm_username" {}
variable "vm_password" {}
variable "vm_ip" {}
variable "name" {}

data "http" "my_public_ip" {
  url = "http://ident.me"
}

# Configure the provider
provider "azurerm" {
  version                     = "1.27.1"
  subscription_id             = "${var.subscription_id}"
  client_id                   = "${var.client_id}"
  client_certificate_path     = "${var.client_certificate_path}"
  client_certificate_password = "${var.client_certificate_password}"
  tenant_id                   = "${var.tenant_id}"
}

# Create a new resource group
resource "azurerm_resource_group" "eve_rg" {
    name     = "eve-ng"
    location = "${var.region}"
}

# Create a virtual network
resource "azurerm_virtual_network" "eve_vnet" {
    name                = "eve-vnet"
    address_space       = ["10.0.0.0/23"]
    location            = "${var.region}"
    resource_group_name = "${azurerm_resource_group.eve_rg.name}"
}

# Create subnet
resource "azurerm_subnet" "eve_subnet" {
    name                 = "eve-subnet"
    resource_group_name  = "${azurerm_resource_group.eve_rg.name}"
    virtual_network_name = "${azurerm_virtual_network.eve_vnet.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IP
resource "azurerm_public_ip" "eve_public_ip" {
    name                         = "eve-public-ip"
    location                     = "${var.region}"
    resource_group_name          = "${azurerm_resource_group.eve_rg.name}"
    allocation_method = "Static"
    domain_name_label = "${var.name}"
}

# Create network interface
resource "azurerm_network_interface" "eve_nic" {
    name                      = "eve-nic"
    location                  = "${var.region}"
    resource_group_name       = "${azurerm_resource_group.eve_rg.name}"
    network_security_group_id = "${azurerm_network_security_group.eve_nsg.id}"

    ip_configuration {
        name                          = "eve-nic-config"
        subnet_id                     = "${azurerm_subnet.eve_subnet.id}"
        private_ip_address_allocation = "Static"
        private_ip_address            = "${var.vm_ip}"
        public_ip_address_id          = "${azurerm_public_ip.eve_public_ip.id}"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "eve_nsg" {
    name                = "eve-network-security-group"
    location            = "${var.region}"
    resource_group_name = "${azurerm_resource_group.eve_rg.name}"

    security_rule {
        name                       = "SSH"
        priority                   = 502
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "${data.http.my_public_ip.body}"
        destination_address_prefix = "${var.vm_ip}"
    }
    security_rule {
        name                       = "HTTPS"
        priority                   = 500
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "${data.http.my_public_ip.body}"
        destination_address_prefix = "${var.vm_ip}"
    }
    security_rule {
        name                       = "deny"
        priority                   = 4096
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_address_prefix      = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        destination_address_prefix = "${var.vm_ip}"
    }
}

resource "azurerm_managed_disk" "eve_storage" {
  name                 = "eve-storage"
  location             = "${var.region}"
  resource_group_name  = "${azurerm_resource_group.eve_rg.name}"
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "${var.disk_size}"
}

# Create a Linux virtual machine
resource "azurerm_virtual_machine" "eve_vm" {
    name                  = "eve-ng"
    location              = "${var.region}"
    resource_group_name   = "${azurerm_resource_group.eve_rg.name}"
    network_interface_ids = ["${azurerm_network_interface.eve_nic.id}"]
    vm_size               = "${var.vm_size}"

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04-LTS"
        version   = "latest"
    }

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    os_profile {
        computer_name  = "eve-ng"
        admin_username = "${var.vm_username}"
        admin_password = "${var.vm_password}"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            #key_data = "${var.ssh_pubkey}"
            key_data = "${file("./id_rsa.pub")}"
            path = "/home/${var.vm_username}/.ssh/authorized_keys"
        }
    }

    storage_data_disk {
        name = "${azurerm_managed_disk.eve_storage.name}"
        create_option = "Attach"
        disk_size_gb = "${var.disk_size}"
        lun = 1
        managed_disk_id = "${azurerm_managed_disk.eve_storage.id}"
    }
}

output "fqdn" {
    value = "${azurerm_public_ip.eve_public_ip.fqdn}"
}

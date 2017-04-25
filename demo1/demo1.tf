# demo1.tf: Linux VM with a managed disk, a load balancer
# ========================
# Variables
# ========================

# Resource group name
variable "RGName" {
  type    = "string"
  default = "terraform-demo1"
}

# Azure location
variable "Location" {
  type    = "string"
  default = "northeurope"
}

# Admin user name
variable "AdminName" {
  type    = "string"
  default = "azureuser"
}

# Admin password
variable "AdminPassword" {
  type    = "string"
  default = "Password1234!"
}

# SSH Public Key
variable "SSHPublicKey" {
  type = "string"
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAIEAkxqTC9KG5Vu2U8zFaEzdcV9+kUEflGNiWEPsy20pI1OTggHxzXnruNXIUmNVqmmC/Q+XMd8gKAgI5xtwF1PtCTkAm1kgX9PYP1rgGKMXcq84pKp01fArk2sxprRR4K95YLEACrypfQ9/pk55JSIUkNy7NN9X474x0lk6wGR3V+8="
}

# OS: Publisher, Offer, SKU, version
variable "OSPublisher" {
  type    = "string"
  default = "Canonical"
}
variable "OSOffer" {
  type    = "string"
  default = "UbuntuServer"
}
variable "OSsku" {
  type    = "string"
  default = "16.04-LTS"
}
variable "OSversion" {
  type    = "string"
  default = "latest"
}

# ========================
# Resources
# ========================

# Resource Group
resource "azurerm_resource_group" "terra_rg" {
  name     = "${var.RGName}"
  location = "${var.Location}"
}

# Virtual Network
resource "azurerm_virtual_network" "terra_vnet" {
  name                = "vnet-demo"
  resource_group_name = "${azurerm_resource_group.terra_rg.name}"
  address_space       = ["10.0.0.0/8"]
  location            = "${var.Location}"
}

# Network Security Group
resource "azurerm_network_security_group" "terra_nsg" {
  name                = "nsg-demo"
  location            = "${var.Location}"
  resource_group_name = "${azurerm_resource_group.terra_rg.name}"

  # rule to allow inbound SSH (TCP 22)
  security_rule {
    name                       = "SSH-inbound"
    priority                   = 1200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Subnet
resource "azurerm_subnet" "terra_subnet" {
  name                      = "subnet-demo"
  resource_group_name       = "${azurerm_resource_group.terra_rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.terra_vnet.name}"
  address_prefix            = "10.0.0.0/16"
  network_security_group_id = "${azurerm_network_security_group.terra_nsg.id}"
}

# Public IP (will be associated to Azure Load Balancer)
resource "azurerm_public_ip" "terra_publicip" {
  name                         = "publicip-demo"
  location                     = "${var.Location}"
  resource_group_name          = "${azurerm_resource_group.terra_rg.name}"
  public_ip_address_allocation = "static"
  domain_name_label            = "publicipvmlinuxcustomscript"
}

# NIC for Linux VM
resource "azurerm_network_interface" "terra_nic0" {
  name                = "nic0-demo"
  location            = "${var.Location}"
  resource_group_name = "${azurerm_resource_group.terra_rg.name}"

  ip_configuration {
    name                          = "configIPNIC0-LinuxVMCustomScript"
    subnet_id                     = "${azurerm_subnet.terra_subnet.id}"
    private_ip_address_allocation = "dynamic"

    load_balancer_inbound_nat_rules_ids     = ["${azurerm_lb_nat_rule.terra_natrule_ssh.id}"]
    load_balancer_backend_address_pools_ids = ["${azurerm_lb_backend_address_pool.terra_backendpool.id}"]
  }
}

# Availability Set
resource "azurerm_availability_set" "terra_as" {
  name                = "as-demo"
  location            = "${var.Location}"
  resource_group_name = "${azurerm_resource_group.terra_rg.name}"
  managed             = true
}

# Load Balancer
resource "azurerm_lb" "terra_lb" {
  name                = "lb-demo"
  location            = "${var.Location}"
  resource_group_name = "${azurerm_resource_group.terra_rg.name}"

  frontend_ip_configuration {
    name                 = "lb-pip-demo"
    public_ip_address_id = "${azurerm_public_ip.terra_publicip.id}"
  }
}

# LB NAT Rule for SSH protocol (TCP 22001 on Internet to TCP 22 on Linux VM)
resource "azurerm_lb_nat_rule" "terra_natrule_ssh" {
  resource_group_name            = "${azurerm_resource_group.terra_rg.name}"
  loadbalancer_id                = "${azurerm_lb.terra_lb.id}"
  name                           = "ssh-access"
  protocol                       = "Tcp"
  frontend_port                  = 2200
  backend_port                   = 22
  frontend_ip_configuration_name = "lb-pip-demo"
}

# Back-en pool for the Load Balancer
resource "azurerm_lb_backend_address_pool" "terra_backendpool" {
  resource_group_name = "${azurerm_resource_group.terra_rg.name}"
  loadbalancer_id     = "${azurerm_lb.terra_lb.id}"
  name                = "backendpool-demo"
}

# Linux VM
resource "azurerm_virtual_machine" "terra_vm1" {
  name                  = "vm-demo"
  location              = "${var.Location}"
  resource_group_name   = "${azurerm_resource_group.terra_rg.name}"
  network_interface_ids = ["${azurerm_network_interface.terra_nic0.id}"]
  vm_size               = "Standard_A2"
  availability_set_id   = "${azurerm_availability_set.terra_as.id}"

  storage_image_reference {
    publisher = "${var.OSPublisher}"
    offer     = "${var.OSOffer}"
    sku       = "${var.OSsku}"
    version   = "${var.OSversion}"
  }

  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "vm-demo"
    admin_username = "${var.AdminName}"
    admin_password = "${var.AdminPassword}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.AdminName}/.ssh/authorized_keys"
      key_data = "${var.SSHPublicKey}"
    }
  }
}

# Create Azure VM Extension for CustomScript
# Creation d une Azure VM Extension de type CustomScript
# More info: https://www.terraform.io/docs/providers/azurerm/r/virtual_machine_extension.html
resource "azurerm_virtual_machine_extension" "terra_customscript1" {
  name                 = "Extension-CustomScript"
  location             = "${var.Location}"
  resource_group_name  = "${azurerm_resource_group.terra_rg.name}"
  virtual_machine_name = "${azurerm_virtual_machine.terra_vm1.name}"
  publisher            = "Microsoft.OSTCExtensions"
  type                 = "CustomScriptForLinux"
  type_handler_version = "1.2"

  settings = <<SETTINGS
    {
        "fileUris": [ "https://raw.githubusercontent.com/pascals-msft/terraform-arm/master/deploy.sh" ],
        "commandToExecute": "bash deploy.sh"
    }
SETTINGS
}

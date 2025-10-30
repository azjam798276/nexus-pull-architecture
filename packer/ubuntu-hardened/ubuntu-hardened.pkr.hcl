# Packer configuration for hardened Ubuntu golden image
# Builds a Proxmox template ready for ansible-pull

packer {
required_plugins {
proxmox = {
version = ">= 1.1.8"
source = "github.com/hashicorp/proxmox"
}
}
}

# Variable definitions
variable "proxmox_url" {
type = string
description = "Proxmox API URL"
default = "https://10.1.0.102:8006/api2/json"
}

variable "proxmox_username" {
type = string
default = "root@pam"
}

variable "proxmox_password" {
type = string
sensitive = true
}

variable "proxmox_node" {
type = string
default = "pve"
}

variable "iso_file" {
type = string
default = "local:iso/ubuntu-22.04.3-live-server-amd64.iso"
}

variable "template_name" {
type = string
default = "ubuntu-22.04-hardened-ansible-pull"
}

variable "vm_id" {
type = number
default = 9000
}

# Source configuration
source "proxmox-iso" "ubuntu-hardened" {
proxmox_url = var.proxmox_url
username = var.proxmox_username
password = var.proxmox_password
node = var.proxmox_node
insecure_skip_tls_verify = true

# ISO configuration
iso_file = var.iso_file

# VM settings
vm_id = var.vm_id
vm_name = var.template_name
template_description = "Hardened Ubuntu 22.04 with ansible-pull dependencies"

# Hardware
cores = 2
memory = 2048

scsi_controller = "virtio-scsi-single"

disks {
type = "scsi"
disk_size = "20G"
storage_pool = "local-lvm"
format = "raw"
io_thread = true
discard = true
}

network_adapters {
model = "virtio"
bridge = "vmbr0"
}

# Cloud-init
cloud_init = true
cloud_init_storage_pool = "local-lvm"

# Boot configuration
boot_command = [
"<esc><wait>",
"e<wait>",
"<down><down><down><end>",
"<bs><bs><bs><bs><wait>",
"autoinstall ds=nocloud-net\\;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ---<wait>",
"<f10><wait>"
]

boot_wait = "5s"

# HTTP server for autoinstall config
http_directory = "http"

# SSH configuration
ssh_username = "ubuntu"
ssh_password = "ubuntu"
ssh_timeout = "20m"
ssh_handshake_attempts = 100

# Completion
unmount_iso = true
}

# Build
build {
sources = ["source.proxmox-iso.ubuntu-hardened"]

# Wait for cloud-init to complete
provisioner "shell" {
inline = [
"while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done"
]
}

# System updates and base packages
provisioner "shell" {
inline = [
"sudo apt-get update",
"sudo apt-get upgrade -y",
"sudo apt-get install -y qemu-guest-agent ansible-core git python3-pip curl wget",
"sudo systemctl enable qemu-guest-agent"
]
}

# Install requests library for webhook callback
provisioner "shell" {
inline = [
"sudo pip3 install requests"
]
}

# Security hardening
provisioner "shell" {
inline = [
# Remove unnecessary packages
"sudo apt-get remove -y snapd",
"sudo apt-get autoremove -y",

# Disable password authentication for SSH
"sudo sed -i 's/^#*PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config",
"sudo sed -i 's/^#*PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config",

# Configure unattended security updates
"sudo apt-get install -y unattended-upgrades",
"echo 'Unattended-Upgrade::Allowed-Origins {' | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades",
"echo ' \"\\${distro_id}:\\${distro_codename}-security\";' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades",
"echo '};' | sudo tee -a /etc/apt/apt.conf.d/50unattended-upgrades",

# Enable automatic security updates
"echo 'APT::Periodic::Update-Package-Lists \"1\";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades",
"echo 'APT::Periodic::Unattended-Upgrade \"1\";' | sudo tee -a /etc/apt/apt.conf.d/20auto-upgrades"
]
}

# Clean up
provisioner "shell" {
inline = [
"sudo apt-get clean",
"sudo rm -rf /tmp/*",
"sudo rm -rf /var/tmp/*",

# Clear machine-id for proper cloud-init on clones
"sudo truncate -s 0 /etc/machine-id",
"sudo rm /var/lib/dbus/machine-id",
"sudo ln -s /etc/machine-id /var/lib/dbus/machine-id",

# Clear cloud-init state
"sudo cloud-init clean --logs --seed"
]
}

# Convert to template
post-processor "shell-local" {
inline = [
"echo 'Template creation complete. VM ID: ${var.vm_id}'"
]
}
}

# Pull-based Nexus VM Module
# Creates a VM with cloud-init bootstrap for self-configuration

terraform {
required_providers {
proxmox = {
source = "bpg/proxmox"
version = "~> 0.50"
}
}
}

resource "proxmox_virtual_environment_vm" "nexus" {
name = var.vm_name
description = "Self-configuring Nexus VM (pull model)"
node_name = var.proxmox_node
pool_id = var.pool_id

# Start immediately after creation
started = true

# Use the hardened golden image
clone {
vm_id = var.template_vm_id
full = true
}

# Resource allocation
cpu {
cores = var.cpu_cores
type = "host"
}

memory {
dedicated = var.memory_mb
}

# Network configuration
network_device {
bridge = var.network_bridge
vlan_id = var.vlan_id
}

# Disk configuration
disk {
datastore_id = var.datastore_id
size = var.disk_size_gb
interface = "scsi0"
iothread = true
discard = "on"
ssd = true
}

# Cloud-init drive (critical for bootstrap)
initialization {
datastore_id = var.datastore_id

ip_config {
ipv4 {
address = var.ip_address
gateway = var.gateway
}
}

dns {
servers = var.dns_servers
}

# CRITICAL: This is where the magic happens
# The user_data contains the self-configuration bootstrap
user_data_file_id = proxmox_virtual_environment_file.cloud_init_user_data.id
}

# Ensure VM waits for cloud-init to prepare
lifecycle {
ignore_changes = [
started,
]
}
}

# Upload the cloud-init configuration to Proxmox
resource "proxmox_virtual_environment_file" "cloud_init_user_data" {
content_type = "snippets"
datastore_id = var.datastore_id
node_name = var.proxmox_node

source_raw {
data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
hostname = var.vm_name
ansible_repo_url = var.ansible_repo_url
ansible_playbook = var.ansible_playbook
webhook_url = var.webhook_url
git_token_secret = var.git_token_secret # For private repos
})
file_name = "${var.vm_name}-cloud-init.yaml"
}
}

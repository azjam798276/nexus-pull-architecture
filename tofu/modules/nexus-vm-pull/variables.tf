variable "vm_name" {
description = "Name of the VM"
type = string
}

variable "proxmox_node" {
description = "Proxmox node name"
type = string
}

variable "pool_id" {
description = "Proxmox resource pool"
type = string
default = null
}

variable "template_vm_id" {
description = "ID of the golden image template"
type = number
}

variable "cpu_cores" {
description = "Number of CPU cores"
type = number
default = 2
}

variable "memory_mb" {
description = "Memory in MB"
type = number
default = 4096
}

variable "disk_size_gb" {
description = "Disk size in GB"
type = number
default = 50
}

variable "datastore_id" {
description = "Proxmox datastore ID"
type = string
default = "local-lvm"
}

variable "network_bridge" {
description = "Network bridge"
type = string
default = "vmbr0"
}

variable "vlan_id" {
description = "VLAN ID (optional)"
type = number
default = null
}

variable "ip_address" {
description = "Static IP address (CIDR notation)"
type = string
}

variable "gateway" {
description = "Network gateway"
type = string
}

variable "dns_servers" {
description = "DNS servers"
type = list(string)
default = ["8.8.8.8", "8.8.4.4"]
}

variable "ansible_repo_url" {
description = "Git repository containing Ansible playbooks"
type = string
}

variable "ansible_playbook" {
description = "Main playbook to execute"
type = string
default = "nexus.yml"
}

variable "webhook_url" {
description = "Webhook endpoint for status reporting"
type = string
}

variable "git_token_secret" {
description = "Git access token for private repos (use Vault in production)"
type = string
sensitive = true
default = ""
}

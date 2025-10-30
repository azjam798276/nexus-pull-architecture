variable "proxmox_endpoint" {
description = "Proxmox API endpoint"
type = string
}

variable "proxmox_username" {
description = "Proxmox API username"
type = string
}

variable "proxmox_password" {
description = "Proxmox API password"
type = string
sensitive = true
}

variable "proxmox_insecure" {
description = "Skip TLS verification"
type = bool
default = true
}

variable "proxmox_node" {
description = "Proxmox node name"
type = string
}

variable "template_vm_id" {
description = "Golden image template VM ID"
type = number
}

variable "ansible_repo_url" {
description = "Ansible playbooks Git repository"
type = string
}

variable "git_token" {
description = "Git access token"
type = string
sensitive = true
default = ""
}

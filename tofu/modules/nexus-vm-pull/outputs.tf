output "vm_id" {
description = "ID of the created VM"
value = proxmox_virtual_environment_vm.nexus.id
}

output "vm_name" {
description = "Name of the created VM"
value = proxmox_virtual_environment_vm.nexus.name
}

output "ip_address" {
description = "IP address of the VM"
value = var.ip_address
}

output "cloud_init_file_id" {
description = "ID of the cloud-init configuration file"
value = proxmox_virtual_environment_file.cloud_init_user_data.id
}

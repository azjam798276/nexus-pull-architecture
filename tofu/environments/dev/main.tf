terraform {
required_version = ">= 1.6"

# PHASE 2: Uncomment after MinIO setup
# backend "s3" {
# bucket = "opentofu-state-storage"
# key = "dev/nexus/terraform.tfstate"
# region = "us-east-1"
# endpoint = "https://minio.internal.corp.com:9000"
# skip_credentials_validation = true
# skip_metadata_api_check = true
# force_path_style = true
# use_lockfile = true
# }

required_providers {
proxmox = {
source = "bpg/proxmox"
version = "~> 0.50"
}
}
}

provider "proxmox" {
endpoint = var.proxmox_endpoint
username = var.proxmox_username
password = var.proxmox_password
insecure = var.proxmox_insecure

ssh {
agent = true
}
}

module "nexus_dev" {
source = "../../modules/nexus-vm-pull"

vm_name = "nexus-dev-01"
proxmox_node = var.proxmox_node
template_vm_id = var.template_vm_id

cpu_cores = 4
memory_mb = 8192
disk_size_gb = 100

ip_address = "10.1.0.150/24"
gateway = "10.1.0.1"
dns_servers = ["8.8.8.8"]

ansible_repo_url = var.ansible_repo_url
ansible_playbook = "nexus.yml"
webhook_url = "http://10.1.0.102:9191/webhook"

# For private repos (use Vault in production!)
git_token_secret = var.git_token
}

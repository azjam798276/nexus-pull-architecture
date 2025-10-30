proxmox_endpoint = "https://10.1.0.102:8006"
proxmox_username = "root@pam"
proxmox_node = "pve"
template_vm_id = 9000 # CHANGE: ID of your Packer-built template

# CHANGE: URL to your ansible-playbooks repo
ansible_repo_url = "https://github.com/YOUR_USER/nexus-ansible-playbooks.git"

# For private repos, set this in terraform.tfvars (not committed!)
# git_token = "ghp_xxxxxxxxxxxxx"

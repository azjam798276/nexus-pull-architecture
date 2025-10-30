# Hardened Ubuntu Golden Image

Packer configuration for building a hardened Ubuntu 22.04 template with ansible-pull dependencies.

## Prerequisites
1. Download Ubuntu 22.04 Server ISO to Proxmox
2. Install Packer: https://developer.hashicorp.com/packer/install

## Build Instructions

### Set Proxmox password
```bash
export PKR_VAR_proxmox_password="your-proxmox-password"
```

### Initialize Packer
```bash
packer init ubuntu-hardened.pkr.hcl
```

### Validate configuration
```bash
packer validate -var-file=example.pkrvars.hcl ubuntu-hardened.pkr.hcl
```

### Build template
```bash
packer build -var-file=example.pkrvars.hcl ubuntu-hardened.pkr.hcl
```

## What's Included
- ✅ Ubuntu 22.04 LTS (latest patches)
- ✅ qemu-guest-agent (Proxmox integration)
- ✅ ansible-core (for ansible-pull)
- ✅ git (to clone playbook repos)
- ✅ python3-requests (for webhook callback)
- ✅ Unattended security updates
- ✅ SSH hardening (no password auth)
- ✅ Minimal package set
- ✅ Cloud-init ready

## Template VM ID
Default: **9000**

After building, this template can be cloned by OpenTofu.

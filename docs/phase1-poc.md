# Phase 1: Proof of Concept Implementation

## Objective
Validate the end-to-end "provision-then-pull" workflow with webhook feedback.

## Prerequisites
- Proxmox 8.x with API access
- OpenTofu/Terraform >= 1.6
- Packer >= 1.10
- Git repository for Ansible playbooks (can be GitHub, GitLab, Gitea, etc.)

## Step-by-Step Implementation

### Step 1: Build the Golden Image

```bash
cd packer/ubuntu-hardened

# Set Proxmox credentials
export PKR_VAR_proxmox_password="your-proxmox-password"

# Initialize Packer plugins
packer init ubuntu-hardened.pkr.hcl

# Validate configuration
packer validate -var-file=example.pkrvars.hcl ubuntu-hardened.pkr.hcl

# Build the template (takes 15-20 minutes)
packer build -var-file=example.pkrvars.hcl ubuntu-hardened.pkr.hcl
```

**Expected Result:** VM template with ID 9000 in Proxmox

### Step 2: Deploy Webhook Receiver

```bash
cd scripts/webhook-receiver

# Deploy to Proxmox host
scp * root@10.1.0.102:/tmp/webhook-receiver/
ssh root@10.1.0.102 "cd /tmp/webhook-receiver && bash deploy.sh"

# Verify it's running
curl http://10.1.0.102:9191/
```

**Expected Result:** JSON response `{"service": "ansible-webhook-receiver", "status": "healthy"}`

### Step 3: Publish Ansible Playbooks to Git

```bash
cd ansible-playbooks

# Initialize git repo
git init
git add .
git commit -m "Initial ansible-pull playbooks"

# Push to your Git server
git remote add origin https://github.com/YOUR_USER/nexus-ansible-playbooks.git
git push -u origin main
```

### Step 4: Configure OpenTofu

```bash
cd tofu/environments/dev

# Copy and edit variables
cp example.tfvars terraform.tfvars
nano terraform.tfvars # Update with your values

# Key values to change:
# - proxmox_password
# - template_vm_id (should be 9000 if you followed Step 1)
# - ansible_repo_url (your GitHub repo from Step 3)
```

### Step 5: Provision the VM

```bash
cd tofu/environments/dev

# Initialize OpenTofu
tofu init

# Review the plan
tofu plan

# Apply (creates VM and cloud-init config)
tofu apply
```

**What happens:**
1. ✅ OpenTofu creates VM from template (ID 9000)
2. ✅ Cloud-init runs on first boot
3. ✅ VM runs `/usr/local/bin/first-boot-configure.sh`
4. ✅ Script executes `ansible-pull` to clone and run playbooks
5. ✅ Ansible installs Nexus
6. ✅ Custom callback plugin sends webhook to 10.1.0.102:9191
7. ✅ Webhook receiver logs the status

### Step 6: Verify Success

```bash
# Check VM is running
ssh ubuntu@10.1.0.150 # (or your configured IP)

# Check Nexus is installed and running
sudo systemctl status nexus

# Access Nexus web UI
curl http://10.1.0.150:8081

# Check webhook receiver logs
ssh root@10.1.0.102 "tail -f /var/log/ansible-webhook.log"
```

**Expected webhook payload:**
```json
{
"status": "success",
"hosts": ["localhost"],
"summary": {
"localhost": {
"ok": 15,
"changed": 8,
"unreachable": 0,
"failed": 0
}
},
"playbook": "nexus.yml",
"timestamp": "2024-10-30T12:34:56.789Z",
"client_ip": "10.1.0.150"
}
```

## Validation Checklist

- [ ] Packer template (ID 9000) exists in Proxmox
- [ ] Webhook receiver responds on http://10.1.0.102:9191/
- [ ] Ansible playbooks are pushed to Git
- [ ] `tofu apply` completes successfully
- [ ] VM is created and boots
- [ ] Nexus is installed and accessible on port 8081
- [ ] Webhook receiver logs show "success" status
- [ ] No Docker daemon running on OpenTofu runner (decoupled!)

## Troubleshooting

### VM doesn't configure itself
```bash
# SSH into the VM
ssh ubuntu@10.1.0.150

# Check cloud-init logs
sudo cat /var/log/cloud-init-output.log

# Check ansible-pull logs
sudo cat /var/log/ansible-pull.log

# Manually run the bootstrap script
sudo /usr/local/bin/first-boot-configure.sh
```

### Webhook not received
```bash
# Check if callback plugin is enabled
ssh ubuntu@10.1.0.150
cat /root/.ansible/ansible.cfg # or wherever ansible-pull ran

# Test webhook manually
curl -X POST http://10.1.0.102:9191/webhook \
-H "Content-Type: application/json" \
-d '{"status":"test","hosts":["manual-test"]}'
```

### Git authentication fails
```bash
# For private repos, you need to pass git_token in terraform.tfvars
# OR make the repo public for POC
```

## Success Criteria Met ✅

If all checklist items pass, **Phase 1 POC is complete**!

You have successfully:
- ✅ Decoupled provisioning from configuration
- ✅ Eliminated Docker daemon dependency on OpenTofu runner
- ✅ Implemented autonomous, self-configuring VMs
- ✅ Established asynchronous feedback via webhooks
- ✅ Validated the pull architecture works end-to-end

**Next:** Proceed to Phase 2 for HA backend and runner fleet.

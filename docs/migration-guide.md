# Migration Guide: Push → Pull Architecture

## Understanding the Changes

### What's Being Removed
- ❌ `ansible_navigator_run` provider
- ❌ Docker daemon dependency on runner
- ❌ SSH from runner to guest VMs
- ❌ Synchronous configuration in `tofu apply`
- ❌ Complex runner setup (Ansible, collections, EE)

### What's Being Added
- ✅ Cloud-init bootstrap in VM templates
- ✅ `ansible-pull` execution on guest VMs
- ✅ Git repository for Ansible playbooks
- ✅ Webhook receiver for status reporting
- ✅ Hardened golden images via Packer

## Side-by-Side Comparison

### Old (Push) Architecture
```hcl
# tofu/main.tf (OLD)
resource "proxmox_virtual_environment_vm" "nexus" {
# ... VM creation ...
}

resource "ansible_navigator_run" "configure_nexus" {
playbook = "nexus.yml"

provisioner "remote-exec" {
connection {
host = proxmox_virtual_environment_vm.nexus.ipv4_addresses[0]
private_key = file("~/.ssh/id_rsa")
}
}

depends_on = [proxmox_virtual_environment_vm.nexus]
}
```

**Issues:**
- Requires Docker on runner
- Blocks on SSH connection
- Single failure point cascades
- Complex dependency chain

### New (Pull) Architecture
```hcl
# tofu/main.tf (NEW)
resource "proxmox_virtual_environment_vm" "nexus" {
# ... VM creation ...

initialization {
user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
}
}

resource "proxmox_virtual_environment_file" "cloud_init" {
source_raw {
data = templatefile("user-data.yaml.tftpl", {
ansible_repo_url = var.ansible_repo_url
webhook_url = var.webhook_url
})
}
}
```

**Benefits:**
- No Docker required
- No SSH from runner
- VM self-configures asynchronously
- Decoupled, autonomous components

## Step-by-Step Migration

### Step 1: Audit Current Infrastructure
```bash
# Identify all resources using ansible_navigator_run
cd nexus-sandbox-framework
grep -r "ansible_navigator_run" .

# List VMs that will need migration
tofu state list | grep proxmox_virtual_environment_vm
```

### Step 2: Set Up Parallel Environment
```bash
# Clone and set up new repo (use the setup script!)
bash setup-pull-architecture-repo.sh

# This creates nexus-pull-architecture/ with all new code
```

### Step 3: Build Golden Image
```bash
cd nexus-pull-architecture/packer/ubuntu-hardened
export PKR_VAR_proxmox_password="your-password"
packer build ubuntu-hardened.pkr.hcl
```

### Step 4: Migrate Ansible Code
```bash
# Copy your existing Ansible playbooks
cp -r ~/nexus-sandbox-framework/ansible/* \
~/nexus-pull-architecture/ansible-playbooks/

# Add the callback plugin
# (Already included in new repo structure)

# Update ansible.cfg to enable callback
# (Already configured in new repo)

# Push to Git
cd ~/nexus-pull-architecture/ansible-playbooks
git init
git add .
git commit -m "Migrated Ansible playbooks for pull model"
git remote add origin https://github.com/YOUR_USER/nexus-ansible-playbooks.git
git push -u origin main
```

### Step 5: Deploy Webhook Receiver
```bash
cd nexus-pull-architecture/scripts/webhook-receiver
scp * root@10.1.0.102:/tmp/webhook/
ssh root@10.1.0.102 "cd /tmp/webhook && bash deploy.sh"
```

### Step 6: Test New Architecture (Non-Destructive)
```bash
# Deploy a TEST VM using new architecture
cd nexus-pull-architecture/tofu/environments/dev

# Configure for test
cat > terraform.tfvars << EOF
proxmox_endpoint = "https://10.1.0.102:8006"
proxmox_username = "root@pam"
proxmox_password = "your-password"
proxmox_node = "pve"
template_vm_id = 9000
ansible_repo_url = "https://github.com/YOUR_USER/nexus-ansible-playbooks.git"
EOF

# Deploy test VM
tofu init
tofu plan
tofu apply

# Validate it works
# - Check webhook receiver logs
# - SSH to VM and verify Nexus is running
# - Confirm no Docker was used on runner
```

### Step 7: Cutover Strategy

**Option A: Big Bang (Small environments)**
1. Schedule maintenance window
2. Destroy all old VMs: `cd nexus-sandbox-framework && tofu destroy`
3. Deploy with new architecture: `cd nexus-pull-architecture && tofu apply`

**Option B: Rolling Migration (Production)**
1. Deploy new VMs alongside old ones
2. Update load balancers to point to new VMs
3. Drain traffic from old VMs
4. Destroy old VMs when ready

**Option C: Blue-Green**
1. Deploy full new environment (green)
2. Test thoroughly
3. Switch DNS/LB to green
4. Keep blue as rollback
5. Destroy blue after confidence period

### Step 8: Update CI/CD Pipelines
```yaml
# Old pipeline (GitLab CI example)
deploy:
script:
- cd nexus-sandbox-framework
- tofu init
- tofu apply -auto-approve
# Requires: Docker, Ansible, SSH keys

# New pipeline
deploy:
script:
- cd nexus-pull-architecture/tofu/environments/prod
- tofu init
- tofu apply -auto-approve
# VM self-configures asynchronously
# Requires: Only terraform-provider-proxmox

# Optional: Wait for configuration
verify:
script:
- ./scripts/wait-for-webhook.sh $VM_IP
needs: [deploy]
```

## Rollback Plan

If issues arise during migration:

### Immediate Rollback
```bash
# New architecture failing
cd nexus-pull-architecture/tofu/environments/prod
tofu destroy -auto-approve

# Redeploy old architecture
cd nexus-sandbox-framework
tofu apply -auto-approve
```

### Partial Rollback
```bash
# Keep new VMs running, but stop new deployments
# Troubleshoot issues while old system handles load
```

## Common Migration Issues

### Issue: "Cloud-init not running"
**Symptom:** VM boots but doesn't configure itself

**Solution:**
```bash
# SSH to VM
ssh ubuntu@VM_IP

# Check cloud-init status
cloud-init status --wait

# View logs
sudo cat /var/log/cloud-init-output.log

# Manually trigger if needed
sudo cloud-init clean
sudo cloud-init init
sudo cloud-init modules --mode=config
sudo cloud-init modules --mode=final
```

### Issue: "Ansible-pull fails with git auth error"
**Symptom:** Can't clone playbook repository

**Solution:**
```bash
# For private repos, ensure git_token is set in terraform.tfvars
# OR make repo public for testing

# Verify git access from VM
ssh ubuntu@VM_IP
git clone https://github.com/YOUR_USER/nexus-ansible-playbooks.git /tmp/test
```

### Issue: "Webhook never received"
**Symptom:** No status updates in logs

**Solution:**
```bash
# Check webhook receiver is running
ssh root@10.1.0.102
systemctl status webhook.service

# Check firewall
iptables -L | grep 9191

# Test manually from VM
ssh ubuntu@VM_IP
curl -X POST http://10.1.0.102:9191/webhook -d '{"test":"data"}'

# Check ansible.cfg has callback enabled
cat /path/to/ansible-playbooks/ansible.cfg | grep callback
```

## Validation Checklist

Before considering migration complete:

- [ ] All new VMs using pull architecture
- [ ] Old `nexus-sandbox-framework` can be safely deleted
- [ ] No Docker daemon running on any OpenTofu runner
- [ ] Webhook receiver logging all configuration runs
- [ ] CI/CD pipelines updated and tested
- [ ] Team trained on new troubleshooting procedures
- [ ] Documentation updated in wiki/confluence
- [ ] Rollback procedure tested and documented
- [ ] Monitoring/alerting configured for new architecture
- [ ] Post-migration review scheduled

## Timeline Estimate

| Phase | Duration | Effort |
|-------|----------|--------|
| Preparation (golden image, webhook) | 1-2 days | 1 person |
| Ansible migration and testing | 2-3 days | 1 person |
| Parallel testing (new architecture) | 3-5 days | 2 people |
| Production cutover | 1 day | 3 people |
| Monitoring and validation | 1 week | 1 person |
| **Total** | **2-3 weeks** | **varies** |

## Success Criteria

Migration is successful when:

✅ All VMs self-configure via ansible-pull
✅ No manual intervention required for provisioning
✅ Webhook receiver shows 100% of runs
✅ Zero Docker-related failures on runners
✅ Team can troubleshoot new architecture
✅ Old architecture fully decomissioned
✅ Documentation complete and accurate

**Congratulations!** You've successfully migrated to the pull architecture.

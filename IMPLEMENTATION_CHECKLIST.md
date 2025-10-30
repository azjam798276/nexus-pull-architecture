Implementation Checklist: Pull Architecture
Use this checklist to track your progress through the implementation phases.
Pre-Implementation
[ ] Read architectural treatise (understand WHY)
[ ] Review existing push architecture at https://github.com/azjam798276/nexus-sandbox-framework
[ ] Identify what needs to be migrated
[ ] Schedule implementation timeline (2-3 weeks recommended)
[ ] Prepare Proxmox environment (confirm API access, storage, network)

Phase 0: Repository Setup
Create New Repository Structure
[ ] Run bash setup-pull-architecture-repo.sh
[ ] Verify directory structure created correctly
[ ] Review generated files and documentation
[ ] Customize .gitignore if needed
Version Control Setup
[ ] Create GitHub/GitLab repository: nexus-pull-architecture
[ ] Push main repository:
cd nexus-pull-architecturegit remote add origin <YOUR_REPO_URL>git push -u origin main


[ ] Create second repository: nexus-ansible-playbooks
[ ] Push Ansible playbooks:
cd ansible-playbooksgit initgit add .git commit -m "Initial ansible-pull playbooks"git remote add origin <YOUR_ANSIBLE_REPO_URL>git push -u origin main


[ ] Set repositories to private (if needed)
[ ] Add team members with appropriate permissions

Phase 1: Proof of Concept
1.1 Build Golden Image (Packer)
[ ] Download Ubuntu 22.04 Server ISO to Proxmox
ssh root@10.1.0.102cd /var/lib/vz/template/isowget https://releases.ubuntu.com/22.04/ubuntu-22.04.3-live-server-amd64.iso


[ ] Update packer/ubuntu-hardened/example.pkrvars.hcl
[ ] Set proxmox_url
[ ] Set proxmox_node
[ ] Verify iso_file path
[ ] Set vm_id (default 9000)
[ ] Set Proxmox password: export PKR_VAR_proxmox_password="your-password"
[ ] Initialize Packer: packer init ubuntu-hardened.pkr.hcl
[ ] Validate config: packer validate -var-file=example.pkrvars.hcl ubuntu-hardened.pkr.hcl
[ ] Build template: packer build -var-file=example.pkrvars.hcl ubuntu-hardened.pkr.hcl
 Expected time: 15-20 minutes
[ ] Verify template exists in Proxmox (VM ID 9000)
[ ] Verify template has cloud-init drive
[ ] Test template by manually creating a clone (optional)
1.2 Deploy Webhook Receiver
[ ] Review webhook receiver code: scripts/webhook-receiver/webhook_receiver.py
[ ] Copy files to Proxmox host:
cd scripts/webhook-receiverscp * root@10.1.0.102:/tmp/webhook/


[ ] Deploy service:
ssh root@10.1.0.102 "cd /tmp/webhook && bash deploy.sh"


[ ] Verify service is running:
ssh root@10.1.0.102 "systemctl status webhook.service"


[ ] Test health endpoint: curl http://10.1.0.102:9191/
[ ] Test webhook endpoint:
curl -X POST http://10.1.0.102:9191/webhook \  -H "Content-Type: application/json" \  -d '{"status":"test","hosts":["test-vm"],"playbook":"test.yml"}'


[ ] Verify logs: ssh root@10.1.0.102 "tail -f /var/log/ansible-webhook.log"
1.3 Customize Ansible Playbooks
[ ] Review ansible-playbooks/nexus.yml
[ ] Customize for your application (or keep Nexus for POC)
[ ] Update ansible-playbooks/requirements.yml if using custom collections
[ ] Verify ansible-playbooks/ansible.cfg has callback enabled
[ ] Review ansible-playbooks/plugins/callback/status_webhook.py
[ ] Test playbook locally (optional):
ansible-playbook nexus.yml -i localhost, --connection=local


[ ] Push changes to Git:
cd ansible-playbooksgit add .git commit -m "Customized playbooks"git push


1.4 Configure OpenTofu
[ ] Navigate to: cd tofu/environments/dev
[ ] Copy example: cp example.tfvars terraform.tfvars
[ ] Edit terraform.tfvars:
[ ] Set proxmox_endpoint
[ ] Set proxmox_username
[ ] Set proxmox_password (or use env var)
[ ] Set proxmox_node
[ ] Set template_vm_id (9000 from Packer)
[ ] Set ansible_repo_url (your GitHub URL)
[ ] Set git_token if private repo
[ ] Review main.tf - understand what it does
[ ] Review tofu/modules/nexus-vm-pull/ - understand the module
1.5 Deploy Test VM
[ ] Initialize OpenTofu: tofu init
[ ] Validate configuration: tofu validate
[ ] Plan deployment: tofu plan
[ ] Review planned changes carefully
[ ] Verify IP address doesn't conflict
[ ] Apply deployment: tofu apply
[ ] Note: Should complete quickly (no waiting for config!)
[ ] Verify VM created in Proxmox
[ ] Watch VM boot in Proxmox console
1.6 Verify Self-Configuration
[ ] Monitor webhook receiver logs in real-time:
ssh root@10.1.0.102 "tail -f /var/log/ansible-webhook.log"


[ ] SSH into the VM: ssh ubuntu@<VM_IP>
[ ] Check cloud-init completed:
cloud-init status --waitcat /var/log/cloud-init-output.log


[ ] Check ansible-pull ran:
sudo cat /var/log/ansible-pull.log


[ ] Check first-boot flag: ls -l /var/run/first-boot-configured
[ ] Verify application is running (Nexus example):
systemctl status nexuscurl http://localhost:8081


[ ] Check webhook was sent: Look for JSON payload in webhook logs
1.7 Validation and Testing
[ ] Access application from external network: curl http://<VM_IP>:8081
[ ] Verify no Docker daemon on runner: docker ps (should not exist)
[ ] Verify OpenTofu state shows VM as created
[ ] Query webhook status endpoint: curl http://10.1.0.102:9191/status
[ ] Verify webhook shows "success" status
[ ] Test idempotency: Reboot VM, verify it doesn't reconfigure
[ ] Test destruction: tofu destroy and verify cleanup
Phase 1 Success Criteria
 All must be true:
[ ] Golden image (ID 9000) exists in Proxmox
[ ] Webhook receiver responds on port 9191
[ ] tofu apply completes in under 2 minutes
[ ] VM boots and self-configures without manual intervention
[ ] Application (Nexus) is accessible and functional
[ ] Webhook receiver logged success status
[ ] No Docker daemon running on OpenTofu runner
[ ] Can destroy and recreate VM successfully
If all checked:  Phase 1 Complete! Proceed to Phase 2.

Phase 2: High-Availability Backend
2.1 Deploy MinIO (S3 Backend)
Option A: Single-Node (POC/Dev)
[ ] SSH to Proxmox host: ssh root@10.1.0.102
[ ] Download MinIO:
wget https://dl.min.io/server/minio/release/linux-amd64/miniochmod +x miniosudo mv minio /usr/local/bin/


[ ] Create data directory: sudo mkdir -p /mnt/minio-data
[ ] Create systemd service (see Phase 2 docs)
[ ] Configure credentials (use strong passwords!)
[ ] Start service: systemctl start minio
[ ] Verify running: systemctl status minio
[ ] Access console: http://10.1.0.102:9001
Option B: Distributed (Production)
[ ] Deploy 4+ MinIO nodes across Proxmox hosts
[ ] Configure erasure coding
[ ] Set up load balancer for MinIO endpoints
[ ] Follow: https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-multi-node-multi-drive.html
2.2 Configure MinIO
[ ] Install mc (MinIO Client):
wget https://dl.min.io/client/mc/release/linux-amd64/mcchmod +x mc && sudo mv mc /usr/local/bin/


[ ] Configure alias: mc alias set local http://10.1.0.102:9000 <user> <pass>
[ ] Create bucket: mc mb local/opentofu-state-storage
[ ] Enable versioning: mc version enable local/opentofu-state-storage
[ ] Test upload: echo "test" | mc pipe local/opentofu-state-storage/test.txt
[ ] Verify: mc ls local/opentofu-state-storage/
[ ] Set lifecycle policies (optional, for old version cleanup)
2.3 Migrate OpenTofu to S3 Backend
[ ] Backup current state: cp terraform.tfstate terraform.tfstate.backup
[ ] Edit tofu/environments/dev/main.tf
[ ] Uncomment backend "s3" block
[ ] Update backend configuration:
[ ] Set endpoint to MinIO URL
[ ] Set access_key and secret_key
[ ] Verify use_lockfile = true is set
[ ] Initialize migration: tofu init -migrate-state
[ ] Confirm migration when prompted
[ ] Verify state in MinIO: mc ls local/opentofu-state-storage/dev/nexus/
[ ] Test locking: Run tofu apply in two terminals simultaneously
[ ] Second should fail with lock error
[ ] Delete local state files (after confirming migration worked):
rm terraform.tfstate terraform.tfstate.backup


2.4 Create Runner Fleet
[ ] Create 3 runner VMs (can use basic Ubuntu, not hardened template)
[ ] On each runner, install:
[ ] OpenTofu: curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh
[ ] Git: apt-get install -y git
[ ] SSH keys for Git access
[ ] Clone infrastructure repo on each runner
[ ] Configure MinIO credentials on each runner (environment variables or ~/.aws/credentials)
[ ] Test state access from each runner:
cd tofu/environments/devtofu inittofu plan


[ ] Verify all runners can read/write shared state
2.5 Deploy HAProxy Load Balancer
[ ] Install HAProxy: apt-get install -y haproxy
[ ] Configure HAProxy (see Phase 2 docs for full config)
[ ] Key settings:
[ ] Frontend on port 9000
[ ] Backend pool with 3 runners
[ ] TCP health checks on SSH port 22
[ ] Round-robin load balancing
[ ] Restart HAProxy: systemctl restart haproxy
[ ] Enable stats page on port 8404
[ ] Test connection via HAProxy:
ssh -p 9000 root@10.1.0.102# Note which runner you connected to


[ ] Test failover:
[ ] Shutdown one runner
[ ] Connect again via HAProxy
[ ] Should connect to different runner
[ ] Check stats: curl http://10.1.0.102:8404/stats
2.6 Update CI/CD Pipelines
[ ] Update deployment scripts to use HAProxy endpoint
[ ] Change from: ssh root@10.1.0.103
[ ] Change to: ssh -p 9000 root@10.1.0.102
[ ] Test CI/CD job triggers successfully
[ ] Verify job can run on any runner (stateless)
Phase 2 Success Criteria
 All must be true:
[ ] MinIO is running and storing OpenTofu state
[ ] State versioning is enabled
[ ] State locking prevents concurrent applies
[ ] 3+ runners can all access shared state
[ ] HAProxy routes connections to healthy runners
[ ] Failure of one runner doesn't impact operations
[ ] CI/CD targets single HAProxy endpoint
[ ] No local state files on any runner
If all checked:  Phase 2 Complete! Proceed to Phase 3.

Phase 3: Enterprise Observability
Choose Your Observability Pattern
Recommended progression:
Start with: Enhanced Webhooks (current)
Add: Prometheus metrics + Grafana
Evaluate: ARA framework (if audit requirements increase)
Consider: Consul (if moving to service-oriented architecture)
3.1 Enhanced Webhook (Current - Improve)
[ ] Review webhook receiver logs
[ ] Add log rotation:
cat > /etc/logrotate.d/ansible-webhook << EOF/var/log/ansible-webhook.log {    daily    rotate 30    compress    delaycompress    missingok    notifempty}EOF


[ ] Create dashboard script to query recent statuses
[ ] Set up email alerts for failures (using webhook data)
[ ] Document webhook payload structure for team
3.2 Prometheus + Grafana (Recommended Next Step)
[ ] Install Prometheus
[ ] Install Grafana
[ ] Update webhook receiver to expose /metrics endpoint
[ ] Add Prometheus counter: ansible_runs_total{status, playbook}
[ ] Add Prometheus histogram: ansible_run_duration_seconds{playbook}
[ ] Configure Prometheus to scrape webhook receiver
[ ] Create Grafana dashboard:
[ ] Panel: Success rate over time
[ ] Panel: Failed runs (recent)
[ ] Panel: Run duration by playbook
[ ] Panel: Runs per host
[ ] Set up Grafana alerts:
[ ] Alert on: Failed run
[ ] Alert on: No runs for 24h (drift detection)
[ ] Document dashboard usage for team
3.3 ARA Framework (If Audit Requirements Exist)
[ ] Deploy ARA server (Docker or VM)
[ ] Configure PostgreSQL backend
[ ] Update ansible-playbooks/ansible.cfg:
[ ] Change callback to ara_default
[ ] Set api_server to ARA URL
[ ] Update golden image to include ARA client
[ ] Rebuild golden image with Packer
[ ] Test with new VM deployment
[ ] Verify playbook runs appear in ARA web UI
[ ] Configure retention policy (how long to keep data)
[ ] Train team on ARA interface
[ ] Document how to query ARA for troubleshooting
3.4 Consul Service Discovery (If Service-Oriented)
[ ] Deploy Consul cluster
[ ] Update Ansible playbooks to register services
[ ] Add health checks to Consul registration
[ ] Create monitoring script to query Consul
[ ] Update CI/CD to wait for Consul health before proceeding
[ ] Document service discovery patterns for team
Phase 3 Success Criteria
 Choose based on your needs:
Minimum (Enhanced Webhooks):
[ ] All configuration runs are logged
[ ] Failed runs are immediately visible
[ ] Logs are retained and rotated
[ ] Team knows how to query status
Recommended (+ Prometheus/Grafana):
[ ] Real-time metrics dashboard
[ ] Alerts fire on failures within 5 minutes
[ ] Historical trends visible (success rate, duration)
[ ] Team uses dashboard daily
Advanced (+ ARA):
[ ] Full audit trail of all Ansible tasks
[ ] Searchable history of playbook runs
[ ] Compliance reporting available
[ ] Troubleshooting via web UI
If criteria met:  Phase 3 Complete! Architecture fully implemented.

Post-Implementation
Documentation
[ ] Update team wiki/confluence
[ ] Document new troubleshooting procedures
[ ] Create runbooks for common issues
[ ] Record architecture decision records (ADRs)
Training
[ ] Train team on new architecture
[ ] Walkthrough troubleshooting scenarios
[ ] Practice rollback procedures
[ ] Review security implications
Migration (If Applicable)
[ ] Follow docs/migration-guide.md
[ ] Schedule migration window
[ ] Migrate workloads from old push architecture
[ ] Decomission old infrastructure
[ ] Archive old repository
Monitoring
[ ] Set up alerts for webhook receiver failures
[ ] Monitor MinIO disk usage
[ ] Monitor runner fleet health
[ ] Set up capacity alerts (95% usage)
Security Hardening
[ ] Rotate MinIO credentials
[ ] Implement Vault for Git tokens (remove hardcoded)
[ ] Review firewall rules
[ ] Enable TLS for MinIO
[ ] Enable TLS for webhook receiver
[ ] Audit who has Proxmox API access
Optimization
[ ] Review golden image for unnecessary packages
[ ] Tune Ansible playbook performance
[ ] Optimize cloud-init scripts
[ ] Consider caching ansible-galaxy collections

Maintenance Schedule
Daily
[ ] Check webhook receiver logs for failures
[ ] Review Grafana dashboard
Weekly
[ ] Verify MinIO backups
[ ] Check disk usage on MinIO
[ ] Review runner fleet health in HAProxy stats
Monthly
[ ] Update golden image with security patches
[ ] Rebuild and test golden image
[ ] Update Ansible collections in playbooks
[ ] Review and update documentation
Quarterly
[ ] Conduct disaster recovery drill
[ ] Review and update runbooks
[ ] Security audit of credentials and access
[ ] Team retrospective on architecture

Success Metrics (Track These!)
Metric
Target
How to Measure
Provisioning Time
< 2 min
tofu apply duration
Configuration Success Rate
> 99%
Webhook success / total
MTTD (Mean Time To Detect failures)
< 10 min
Webhook timestamp - failure time
MTTR (Mean Time To Recover)
< 30 min
Ticket closed - ticket opened
Runner Availability
> 99.9%
HAProxy uptime
State Lock Contention
< 1%
Lock failures / total applies


Troubleshooting Quick Reference
VM Not Configuring
ssh ubuntu@<VM_IP>
sudo cat /var/log/cloud-init-output.log | grep -i error
sudo cat /var/log/ansible-pull.log | tail -50

Webhook Not Received
# Test from VM
curl -X POST http://10.1.0.102:9191/webhook -d '{"test":"data"}'

# Check receiver
ssh root@10.1.0.102 "systemctl status webhook.service"
ssh root@10.1.0.102 "tail -f /var/log/ansible-webhook.log"

State Locked
# Find lock ID
tofu plan  # Shows lock ID in error

# Force unlock (use carefully!)
tofu force-unlock <LOCK_ID>

Runner Unhealthy in HAProxy
# Check HAProxy stats
curl http://10.1.0.102:8404/stats | grep runner

# SSH to runner directly
ssh root@10.1.0.103  # Bypass HAProxy

# Check if OpenTofu works
tofu version


Rollback Procedures
Phase 1 Rollback
cd tofu/environments/dev
tofu destroy
# Revert to old push architecture if needed

Phase 2 Rollback (Remove HA Backend)
# Comment out backend block in main.tf
tofu init -migrate-state  # Move state back to local
rm -rf .terraform/
tofu init

Phase 3 Rollback (Remove Observability)
# Disable callbacks in ansible.cfg
callbacks_enabled = 
# Stop services
systemctl stop webhook.service


 Congratulations on completing the implementation!
This architecture represents a significant improvement in:
 Reliability (no Docker daemon failures)
 Security (no SSH from runner to VMs)
 Simplicity (decoupled components)
 Scalability (parallel self-configuration)
 Observability (comprehensive monitoring)
Keep this checklist for future reference and for onboarding new team members.


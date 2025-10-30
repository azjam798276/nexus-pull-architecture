# Phase 2: High-Availability Backend and Runner Fleet

## Objective
Build production-grade, resilient infrastructure for OpenTofu state and execution.

## Architecture Components

### 1. MinIO S3 Backend (State Storage)
- Self-hosted S3-compatible object storage
- Distributed across multiple Proxmox nodes
- Native state locking (no DynamoDB needed!)

### 2. Runner Fleet
- Multiple stateless OpenTofu runner VMs
- All pointing to centralized MinIO backend
- No local state files

### 3. HAProxy Load Balancer
- Single virtual IP for all runners
- Health checking and automatic failover
- Round-robin load distribution

## Implementation Steps

### Step 1: Deploy MinIO Cluster

**Option A: Single-node MinIO (POC/Small environments)**
```bash
# On Proxmox host or dedicated VM
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo mv minio /usr/local/bin/

# Create data directory
sudo mkdir -p /mnt/minio-data

# Create systemd service
sudo cat > /etc/systemd/system/minio.service << 'EOF'
[Unit]
Description=MinIO S3 Storage
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/bin
ExecStart=/usr/local/bin/minio server /mnt/minio-data --console-address ":9001"
Restart=always

Environment="MINIO_ROOT_USER=minioadmin"
Environment="MINIO_ROOT_PASSWORD=minioadmin123"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable minio
sudo systemctl start minio
```

**Option B: Distributed MinIO (Production)**
See: https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-multi-node-multi-drive.html

### Step 2: Configure MinIO

```bash
# Install mc (MinIO Client)
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Configure alias
mc alias set local http://10.1.0.102:9000 minioadmin minioadmin123

# Create bucket for OpenTofu state
mc mb local/opentofu-state-storage

# Enable versioning (critical for state recovery)
mc version enable local/opentofu-state-storage

# Verify
mc ls local/
```

### Step 3: Update OpenTofu to Use S3 Backend

```bash
cd tofu/environments/dev

# Edit main.tf - uncomment the backend block
nano main.tf
```

Update backend configuration:
```hcl
terraform {
backend "s3" {
bucket = "opentofu-state-storage"
key = "dev/nexus/terraform.tfstate"
region = "us-east-1" # Required but ignored
endpoint = "http://10.1.0.102:9000"
access_key = "minioadmin"
secret_key = "minioadmin123"
skip_credentials_validation = true
skip_metadata_api_check = true
skip_region_validation = true
force_path_style = true

# CRITICAL: Enable native S3 locking
use_lockfile = true
}
}
```

```bash
# Migrate existing state to S3 backend
tofu init -migrate-state

# Verify state is in MinIO
mc ls local/opentofu-state-storage/dev/nexus/
```

### Step 4: Create Runner Fleet

```bash
# Create 3 identical runner VMs
cd tofu/environments/prod

# Create runner configuration
cat > runners.tf << 'EOF'
module "runner" {
for_each = toset(["runner01", "runner02", "runner03"])

source = "../../modules/basic-vm" # Create this module

vm_name = "tofu-${each.key}"
proxmox_node = "pve"
cpu_cores = 2
memory_mb = 2048
ip_address = "10.1.0.${index(["runner01", "runner02", "runner03"], each.key) + 103}/24"
}
EOF

tofu apply
```

On each runner, install OpenTofu:
```bash
# SSH to each runner
for i in 103 104 105; do
ssh root@10.1.0.$i << 'RUNNER_SETUP'
# Install OpenTofu
curl -fsSL https://get.opentofu.org/install-opentofu.sh | sh

# Install Git
apt-get update && apt-get install -y git

# Configure to use MinIO backend (via environment or config)
# All state operations will now use S3
RUNNER_SETUP
done
```

### Step 5: Deploy HAProxy Load Balancer

```bash
# On Proxmox host or dedicated VM
apt-get install -y haproxy

# Configure HAProxy
cat > /etc/haproxy/haproxy.cfg << 'EOF'
global
log /dev/log local0
log /dev/log local1 notice
chroot /var/lib/haproxy
stats socket /run/haproxy/admin.sock mode 660 level admin
stats timeout 30s
user haproxy
group haproxy
daemon

defaults
log global
mode tcp
option tcplog
option dontlognull
timeout connect 5000
timeout client 50000
timeout server 50000

# Frontend for OpenTofu runner fleet
listen tofu_runner_fleet
bind 0.0.0.0:9000
mode tcp
balance roundrobin
option tcplog

# Health checks (TCP connection on SSH port)
option tcp-check

# Backend runner pool
server runner01 10.1.0.103:22 check port 22 inter 5s rise 2 fall 3
server runner02 10.1.0.104:22 check port 22 inter 5s rise 2 fall 3
server runner03 10.1.0.105:22 check port 22 inter 5s rise 2 fall 3

# Stats page
listen stats
bind *:8404
mode http
stats enable
stats uri /stats
stats refresh 30s
stats admin if TRUE
EOF

# Restart HAProxy
systemctl restart haproxy
systemctl enable haproxy
```

### Step 6: Test HA Configuration

**Test 1: State Locking**
```bash
# Terminal 1
cd tofu/environments/dev
tofu apply # Starts apply, acquires lock

# Terminal 2 (while first is running)
cd tofu/environments/dev
tofu apply # Should fail with lock error

# Expected: "Error: Error acquiring the state lock"
```

**Test 2: Runner Failover**
```bash
# Connect via HAProxy virtual IP
ssh root@10.1.0.102 -p 9000
# Note which runner you connected to

# Shutdown that runner
ssh root@10.1.0.103 "shutdown -h now"

# Try connecting again via HAProxy
ssh root@10.1.0.102 -p 9000
# Should connect to runner02 or runner03

# Check HAProxy stats
curl http://10.1.0.102:8404/stats
```

**Test 3: State Persistence**
```bash
# Apply from runner01
ssh -p 9000 root@10.1.0.102
cd /path/to/terraform
tofu apply

# Apply from runner02 (same state!)
ssh -p 9000 root@10.1.0.102 # Will round-robin to different runner
cd /path/to/terraform
tofu plan # Should show no changes (state is shared)
```

## Validation Checklist

- [ ] MinIO is running and accessible
- [ ] OpenTofu state bucket exists and is versioned
- [ ] `tofu init -migrate-state` successfully moved state to MinIO
- [ ] State locking prevents concurrent applies
- [ ] All 3 runners can access and modify shared state
- [ ] HAProxy routes connections to healthy runners only
- [ ] HAProxy automatically fails over when a runner goes down
- [ ] CI/CD can target single HAProxy endpoint (port 9000)

## Architecture Benefits Achieved

✅ **No Single Point of Failure**
- State backend: MinIO (can be distributed)
- Execution: 3 runners behind HAProxy
- Network: HAProxy provides single stable endpoint

✅ **State Safety**
- Centralized in MinIO (no local files)
- Versioned (can rollback corrupted state)
- Locked (prevents concurrent modification)

✅ **Operational Simplicity**
- CI/CD points to one IP:port
- Automatic failover (transparent to users)
- Stateless runners (cattle, not pets)

**Next:** Proceed to Phase 3 for enterprise observability.

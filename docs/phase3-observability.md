# Phase 3: Enterprise Observability and Auditing

## Objective
Mature from simple webhooks to comprehensive audit and monitoring capabilities.

## Evolution Path

### Current State (Phase 1)
- ✅ Simple webhook callback
- ✅ Logs to file on receiver
- ✅ Basic success/failure tracking

### Target State (Phase 3)
- 🎯 Full execution history and task-level details
- 🎯 Searchable web UI for audit queries
- 🎯 Integration with enterprise monitoring (Prometheus, Grafana, ELK)
- 🎯 Alerting on configuration failures
- 🎯 Compliance reporting

## Option 1: Upgrade to ARA (Ansible Records Ansible)

### What is ARA?
Full-featured Ansible audit framework with:
- Web UI for browsing playbook runs
- Task-by-task execution details
- Timing and performance metrics
- Search and filtering
- REST API for integration

### Deployment

**Step 1: Install ARA Server**
```bash
# On dedicated VM or container
pip3 install ara[server]

# Initialize database
ara-manage migrate

# Create admin user
ara-manage createsuperuser

# Run server
ara-manage runserver 0.0.0.0:8000
```

**Step 2: Production Deployment (Docker)**
```bash
# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3'
services:
ara:
image: ghcr.io/ansible-community/ara-api:latest
ports:
- "8000:8000"
environment:
ARA_DATABASE_ENGINE: postgresql
ARA_DATABASE_NAME: ara
ARA_DATABASE_USER: ara
ARA_DATABASE_PASSWORD: arapassword
ARA_DATABASE_HOST: postgres
depends_on:
- postgres

postgres:
image: postgres:15
environment:
POSTGRES_DB: ara
POSTGRES_USER: ara
POSTGRES_PASSWORD: arapassword
volumes:
- ara-data:/var/lib/postgresql/data

volumes:
ara-data:
EOF

docker-compose up -d
```

**Step 3: Configure Ansible to Use ARA**

Update `ansible-playbooks/ansible.cfg`:
```ini
[defaults]
# Replace webhook callback with ARA
callback_plugins = /usr/local/lib/python3.10/dist-packages/ara/plugins/callback
callbacks_enabled = ara_default

[ara]
api_client = http
api_server = http://10.1.0.102:8000
```

**Step 4: Update Cloud-Init to Install ARA Client**

Update Packer provisioner:
```bash
sudo pip3 install ara[client]
```

**Step 5: Access ARA Web UI**
```
http://10.1.0.102:8000
```

Browse all playbook runs, search by host, filter by status, drill into task details.

## Option 2: Integration with Enterprise Monitoring

### Prometheus + Grafana Integration

**Modify webhook receiver to expose metrics:**

```python
# Add to webhook_receiver.py
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

# Metrics
ansible_runs_total = Counter(
'ansible_runs_total',
'Total ansible-pull runs',
['status', 'playbook']
)

ansible_run_duration = Histogram(
'ansible_run_duration_seconds',
'Ansible run duration',
['playbook']
)

@app.get("/metrics")
async def metrics():
"""Prometheus metrics endpoint."""
return Response(
content=generate_latest(),
media_type=CONTENT_TYPE_LATEST
)

@app.post("/webhook")
async def receive_webhook(request: Request):
data = await request.json()

# Increment counters
ansible_runs_total.labels(
status=data.get('status'),
playbook=data.get('playbook')
).inc()

# ... rest of webhook logic
```

**Prometheus scrape config:**
```yaml
scrape_configs:
- job_name: 'ansible-webhook'
static_configs:
- targets: ['10.1.0.102:9191']
```

**Grafana Dashboard:**
- Total runs by status
- Success rate over time
- Failed hosts
- Run duration percentiles

### ELK Stack Integration

**Forward webhook payloads to Elasticsearch:**

```python
# Add to webhook_receiver.py
from elasticsearch import Elasticsearch

es = Elasticsearch(['http://elasticsearch:9200'])

@app.post("/webhook")
async def receive_webhook(request: Request):
data = await request.json()

# Index in Elasticsearch
es.index(
index='ansible-pull-status',
document=data
)

# ... rest of logic
```

**Kibana queries:**
- Find all failed runs in last 24h
- Group by playbook and host
- Alert on failures

## Option 3: Consul Service Discovery Pattern

### Why Consul?
- Implicit state: Service health = configuration success
- No explicit webhook needed
- Distributed, HA by design
- Built-in health checks

### Implementation

**Step 1: Deploy Consul Cluster**
```bash
# Single-node dev mode (or full cluster for prod)
docker run -d \
--name=consul \
-p 8500:8500 \
-p 8600:8600/udp \
consul agent -server -ui -bootstrap-expect=1 -client=0.0.0.0
```

**Step 2: Modify Ansible Playbook**

Add final task to register with Consul:
```yaml
# Add to nexus.yml
- name: Register Nexus with Consul
community.general.consul:
service_name: nexus
service_port: 8081
service_address: "{{ ansible_default_ipv4.address }}"
state: present
check:
http: "http://{{ ansible_default_ipv4.address }}:8081"
interval: 10s
timeout: 5s
```

**Step 3: Query Consul for State**

```bash
# Check if Nexus is configured and healthy
curl http://10.1.0.102:8500/v1/health/service/nexus?passing

# Returns JSON of all healthy Nexus instances
# Empty array = not configured or unhealthy
```

**Step 4: CI/CD Integration**

```bash
#!/bin/bash
# Wait for VM to self-configure and become healthy

VM_IP="10.1.0.150"
TIMEOUT=600 # 10 minutes

echo "Waiting for $VM_IP to configure and register..."

for i in $(seq 1 $TIMEOUT); do
HEALTHY=$(curl -s http://10.1.0.102:8500/v1/health/service/nexus?passing | \
jq -r ".[] | select(.Service.Address==\"$VM_IP\") | .Service.ID")

if [ -n "$HEALTHY" ]; then
echo "✅ VM configured successfully and is healthy!"
exit 0
fi

sleep 1
done

echo "❌ Timeout: VM did not become healthy within $TIMEOUT seconds"
exit 1
```

## Comparison Matrix

| Feature | Webhook | ARA | Prometheus/Grafana | Consul |
|---------|---------|-----|-------------------|--------|
| Implementation Effort | Low | Medium | Medium | High |
| Audit Detail | Low | Very High | Medium | Low |
| Real-time Monitoring | Yes | No | Yes | Yes |
| Historical Analysis | Limited | Excellent | Good | Limited |
| Infrastructure Cost | Minimal | Moderate | Moderate | Moderate |
| Learning Curve | Low | Medium | Medium | High |
| Best For | POC/Small | Compliance | DevOps Teams | Service-Oriented |

## Recommended Approach

### Phase 3A: Near-term (2-3 sprints)
1. **Enhance webhook receiver** with Prometheus metrics
2. **Set up Grafana** dashboard for visibility
3. **Configure alerts** for failed runs

### Phase 3B: Long-term (as needed)
1. **Evaluate ARA** if audit requirements increase
2. **Consider Consul** if moving to microservices
3. **Integrate ELK** if centralized logging exists

## Success Metrics

- [ ] All ansible-pull runs are tracked
- [ ] Failed configurations trigger alerts within 5 minutes
- [ ] Historical data retained for compliance (90+ days)
- [ ] Dashboard accessible to ops team
- [ ] Mean time to detect (MTTD) configuration failures < 10 min
- [ ] 99.9% of successful runs reported correctly

## Final Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ Management / Observability Plane │
│ │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ │
│ │ Webhook │ │ ARA │ │ Grafana │ │ Consul │ │
│ │ Receiver │ │ Server │ │Dashboard │ │ Cluster │ │
│ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ │
│ │ │ │ │ │
└───────┼─────────────┼─────────────┼─────────────┼────────────────┘
│ │ │ │
│ HTTP POST │ HTTP POST │ Scrape │ Register
│ (webhook) │ (callback) │ (metrics) │ (service)
│ │ │ │
┌───────▼─────────────▼─────────────▼─────────────▼────────────────┐
│ VM Fleet (Pull Model) │
│ │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ Nexus VM │ │ Nexus VM │ │ Nexus VM │ │
│ │ │ │ │ │ │ │
│ │ ansible-pull │ │ ansible-pull │ │ ansible-pull │ │
│ │ (periodic) │ │ (periodic) │ │ (periodic) │ │
│ └──────┬───────┘ └──────┬───────┘ └──────┬───────┘ │
│ │ │ │ │
└─────────┼─────────────────┼─────────────────┼─────────────────────┘
│ │ │
│ git pull │ │
▼ ▼ ▼
┌─────────────────────────────────────────────┐
│ Git Repo (Ansible Playbooks) │
│ - ansible.cfg (callback configuration) │
│ - nexus.yml (playbook) │
│ - plugins/callback/*.py (webhooks/ARA) │
└─────────────────────────────────────────────┘
▲
│
┌─────────┴─────────────────────────────────────────────────────────┐
│ Provisioning Plane │
│ │
│ ┌──────────┐ ┌──────────────┐ │
│ │ HAProxy │─────────────────▶│ Runner Fleet │ │
│ │ (LB) │ Round-robin │ (Stateless) │ │
│ └──────────┘ └───────┬──────┘ │
│ │ │
│ │ Read/Write State │
│ ▼ │
│ ┌─────────────┐ │
│ │ MinIO │ │
│ │ (S3 Backend)│ │
│ │ + Locking │ │
│ └─────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

**End of Phase 3 Documentation**

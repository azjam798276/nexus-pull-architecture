# Webhook Receiver

Lightweight FastAPI application to receive ansible-pull status updates.

## Quick Deploy to Proxmox Host

### Option 1: Direct deployment
```bash
cd scripts/webhook-receiver
scp * root@10.1.0.102:/tmp/webhook-receiver/
ssh root@10.1.0.102 "cd /tmp/webhook-receiver && bash deploy.sh"
```

### Option 2: Manual installation
```bash
# On Proxmox host
apt-get install -y python3 python3-pip
pip3 install fastapi uvicorn[standard]

# Run directly
python3 webhook_receiver.py
```

## Testing

```bash
# Send test webhook
curl -X POST http://10.1.0.102:9191/webhook \
-H "Content-Type: application/json" \
-d '{
"status": "success",
"hosts": ["test-vm"],
"summary": {"test-vm": {"ok": 5, "changed": 2, "failed": 0}},
"playbook": "test.yml"
}'

# Check status
curl http://10.1.0.102:9191/status
```

## Endpoints

- `GET /` - Health check
- `GET /status` - View recent updates
- `POST /webhook` - Receive status updates (called by Ansible callback)

## Logs

```bash
# Service logs
journalctl -u webhook.service -f

# Application logs
tail -f /var/log/ansible-webhook.log
```

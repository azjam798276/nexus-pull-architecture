# Nexus Ansible Playbooks

Self-contained Ansible repository for autonomous VM configuration via `ansible-pull`.

## Structure
- `ansible.cfg` - Auto-loaded configuration (enables webhook callback)
- `nexus.yml` - Main Nexus installation playbook
- `requirements.yml` - Galaxy dependencies
- `plugins/callback/status_webhook.py` - Custom callback for status reporting

## Usage

### Manual Testing
```bash
ansible-pull -U https://github.com/YOUR_USER/nexus-ansible-playbooks.git nexus.yml
```

### Automatic (via cloud-init)
VMs provisioned with the pull architecture automatically run this on first boot.

## Webhook Callback

The custom callback plugin sends JSON payloads to a configured endpoint:

```json
{
"status": "success",
"hosts": ["localhost"],
"summary": {
"localhost": {
"ok": 15,
"changed": 8,
"unreachable": 0,
"failed": 0,
"skipped": 2
}
},
"playbook": "nexus.yml"
}
```

Configure webhook URL via environment variable:
```bash
export ANSIBLE_WEBHOOK_URL="http://10.1.0.102:9191/webhook"
```

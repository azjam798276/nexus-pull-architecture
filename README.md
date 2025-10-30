# Nexus Pull Architecture

Asynchronous, event-driven infrastructure provisioning using the "provision-then-pull" pattern.

## Architecture Overview

This repository implements **Architecture B** from the architectural treatise:
- **Decoupled**: OpenTofu only provisions base VMs
- **Autonomous**: VMs self-configure via `ansible-pull`
- **Secure**: No SSH credentials stored; uses Vault/token-based auth
- **Resilient**: No docker daemon dependency; no synchronous coupling

## Repository Structure

```
├── tofu/ # OpenTofu infrastructure code
│ ├── modules/
│ │ └── nexus-vm-pull/ # Reusable VM module with cloud-init
│ └── environments/ # Environment-specific configs
├── packer/ # Golden image builds
│ └── ubuntu-hardened/ # Hardened Ubuntu template
├── ansible-playbooks/ # Self-contained Ansible repository
│ ├── ansible.cfg # Auto-loaded configuration
│ ├── nexus.yml # Main playbook
│ ├── requirements.yml # Galaxy dependencies
│ ├── roles/ # Custom roles
│ └── plugins/callback/ # Custom webhook callback
└── scripts/ # Helper scripts

```

## Quick Start

### Prerequisites
- Proxmox 8.x with API access
- OpenTofu >= 1.6
- Packer >= 1.10

### Phase 1: Build Golden Image
```bash
cd packer/ubuntu-hardened
packer build ubuntu-hardened.pkr.hcl
```

### Phase 2: Deploy Infrastructure
```bash
cd tofu/environments/dev
tofu init
tofu plan
tofu apply
```

### Phase 3: Observe Self-Configuration
The VM will automatically configure itself via `ansible-pull` on first boot.

## Key Differences from Push Architecture

| Aspect | Old (Push) | New (Pull) |
|--------|-----------|-----------|
| Runner complexity | High (Docker, Ansible, Collections) | Low (Just terraform-provider-proxmox) |
| Security model | Runner needs SSH into VMs | VMs need outbound HTTPS only |
| Failure domain | Docker crash kills entire apply | Docker not involved |
| State sync | Synchronous (blocks apply) | Asynchronous (apply completes immediately) |
| Observability | Built-in (apply output) | Custom (webhooks/ARA) |

## Documentation
- [Phase 1: POC Implementation](docs/phase1-poc.md)
- [Phase 2: HA Backend Setup](docs/phase2-ha-backend.md)
- [Phase 3: Observability](docs/phase3-observability.md)


## Quick Reference

### Key Files
- `tofu/modules/nexus-vm-pull/` - Reusable VM module (the heart of pull architecture)
- `packer/ubuntu-hardened/` - Golden image builder
- `ansible-playbooks/` - Self-contained Ansible repository
- `scripts/webhook-receiver/` - Status reporting service

### Common Commands

**Build golden image:**
```bash
cd packer/ubuntu-hardened
export PKR_VAR_proxmox_password="your-password"
packer build ubuntu-hardened.pkr.hcl
```

**Deploy VM:**
```bash
cd tofu/environments/dev
tofu init
tofu plan
tofu apply
```

**Check webhook status:**
```bash
curl http://10.1.0.102:9191/status | jq
```

**View webhook logs:**
```bash
ssh root@10.1.0.102
tail -f /var/log/ansible-webhook.log
```

### Troubleshooting

**VM not configuring?**
```bash
ssh ubuntu@VM_IP
sudo cat /var/log/cloud-init-output.log
sudo cat /var/log/ansible-pull.log
```

**State locked?**
```bash
tofu force-unlock LOCK_ID
```

**Reset cloud-init:**
```bash
sudo cloud-init clean --logs --seed
sudo reboot
```

## Architecture Decisions

### Why Pull over Push?
- **Decoupling**: Runner only provisions; VM self-configures
- **Resilience**: No Docker daemon dependency
- **Security**: No SSH from runner to VMs
- **Simplicity**: Runner needs only terraform-provider-proxmox

### Why Cloud-Init?
- Industry standard for VM bootstrap
- Supported by all cloud providers
- Idempotent and declarative
- No external dependencies

### Why Webhook over Other Patterns?
- Lightweight (no heavy framework)
- Easy to implement and test
- Flexible (can forward anywhere)
- Good starting point (can upgrade to ARA later)

### Why MinIO over Cloud S3?
- Self-hosted (no cloud dependency)
- S3-compatible (familiar APIs)
- Native locking support (no DynamoDB needed)
- Cost-effective for self-hosted

## Contributing

This repository follows the architectural patterns described in:
> "An Architectural Treatise on Decoupled Infrastructure Provisioning"

When making changes:
1. Follow the existing module structure
2. Maintain idempotency in all scripts
3. Update documentation
4. Test end-to-end before committing

## License

[Your License Here]

## Support

- **Issues**: [GitHub Issues](https://github.com/YOUR_USER/nexus-pull-architecture/issues)
- **Discussions**: [GitHub Discussions](https://github.com/YOUR_USER/nexus-pull-architecture/discussions)
- **Documentation**: See `docs/` directory

---

**Built with ❤️ following principles of choreography over orchestration**

#!/usr/bin/env bash
# Preflight Check Script
# Validates environment is ready for pull architecture implementation

set -uo pipefail # Keep set -e removed for now

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Tracking
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNED=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Pull Architecture Preflight Check ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check function
check() {
    local name="$1"
    local command="$2"
    local severity="${3:-error}" # error or warn

    printf "%-50s " "Checking $name..."

    # Use bash -c for better handling of complex commands within eval
    if eval "bash -c '$command'" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((CHECKS_PASSED++))
        return 0
    else
        local exit_code=$?
        if [ "$severity" = "error" ]; then
            echo -e "${RED}✗ (code: $exit_code)${NC}"
            ((CHECKS_FAILED++))
        else
            echo -e "${YELLOW}‼ (code: $exit_code)${NC}"
            ((CHECKS_WARNED++))
        fi
        return 1
    fi
}

# API Check function - Special handling for jq exit code
check_api() {
    local name="$1"
    local command="$2"
    local severity="${3:-error}"

    printf "%-50s " "Checking $name..."

    # Run command, capture output and exit code specifically
    local output
    local exit_code
    output=$(eval "$command" 2>&1)
    exit_code=$?

    # jq -e exits 0 on success (data found), 1 on failure (no data/false/null)
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓${NC}"
        ((CHECKS_PASSED++))
        return 0
    else
        if [ "$severity" = "error" ]; then
             echo -e "${RED}✗ (API Error or No Data)${NC}"
             echo "  Raw API response:"
             # Rerun without jq filter for debugging
             eval "$(echo "$command" | sed 's/| jq .*//')" | jq .
            ((CHECKS_FAILED++))
        else
            echo -e "${YELLOW}‼ (API Error or No Data)${NC}"
            ((CHECKS_WARNED++))
        fi
        return 1
    fi
}


check_with_output() {
    local name="$1"
    local command="$2"
    local expected="$3"
    local severity="${4:-error}"

    printf "%-50s " "Checking $name..."

    output=$(eval "$command" 2>/dev/null || echo "")

    if [[ "$output" == *"$expected"* ]]; then
        echo -e "${GREEN}✓${NC} ($output)"
        ((CHECKS_PASSED++))
        return 0
    else
        if [ "$severity" = "error" ]; then
            echo -e "${RED}✗${NC} (got: $output)"
            ((CHECKS_FAILED++))
        else
            echo -e "${YELLOW}‼${NC} (got: $output)" # Changed warning symbol
            ((CHECKS_WARNED++))
        fi
        return 1
    fi
}

echo -e "${BLUE}[1/6] Local Environment Checks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check "Git installed" "command -v git"
check "OpenTofu installed" "command -v tofu"
check "Packer installed" "command -v packer"
check "SSH client installed" "command -v ssh"
check "curl installed" "command -v curl"
check "jq installed" "command -v jq" "warn"

echo ""
echo -e "${BLUE}[2/6] Proxmox Connectivity${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PROXMOX_IP="${PROXMOX_IP:-10.1.0.102}"
PROXMOX_PORT="${PROXMOX_PORT:-8006}"

check "Proxmox host reachable" "ping -c 1 -W 2 $PROXMOX_IP"
check "Proxmox API port open" "curl -k --connect-timeout 2 https://$PROXMOX_IP:$PROXMOX_PORT >/dev/null 2>&1"
check "SSH to Proxmox host" "ssh -o ConnectTimeout=5 -o BatchMode=yes ${PROXMOX_SSH_USER:-root}@$PROXMOX_IP 'exit' 2>/dev/null" "warn"

echo ""
echo -e "${BLUE}[3/6] Proxmox API Checks${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "${PROXMOX_API_TOKEN_ID:-}" ] && [ -n "${PROXMOX_API_TOKEN_SECRET:-}" ]; then
    export PVE_AUTH_HEADER="Authorization: PVEAPIToken=${PROXMOX_API_TOKEN_ID}=${PROXMOX_API_TOKEN_SECRET}"
    NODE_NAME="${PROXMOX_NODE:-pve}"

    # Use check_api function with modified jq command
    api_command="curl -s -k -H \"\$PVE_AUTH_HEADER\" \
        \"https://$PROXMOX_IP:$PROXMOX_PORT/api2/json/nodes/$NODE_NAME/status\" | \
        jq -e '.data | length > 0'" # Check if .data exists and is not empty/null

    check_api "Proxmox API authentication and Node Status" "$api_command"

else
    echo -e "${YELLOW}‼${NC} Proxmox API token not set (skipping API checks)"
    echo "  Export PROXMOX_API_TOKEN_ID and PROXMOX_API_TOKEN_SECRET to test API access"
    ((CHECKS_WARNED++))
fi

echo ""
echo -e "${BLUE}[4/6] Repository Structure${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check "tofu/modules directory exists" "[ -d tofu/modules ]"
check "packer directory exists" "[ -d packer ]"
check "ansible-playbooks directory exists" "[ -d ansible-playbooks ]"
check "scripts directory exists" "[ -d scripts ]"
check "docs directory exists" "[ -d docs ]"
check "Main README exists" "[ -f README.md ]"
check "Implementation checklist exists" "[ -f IMPLEMENTATION_CHECKLIST.md ]"

echo ""
echo -e "${BLUE}[5/6] Critical Files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check "OpenTofu module main.tf" "[ -f tofu/modules/nexus-vm-pull/main.tf ]"
check "Cloud-init template" "[ -f tofu/modules/nexus-vm-pull/templates/user-data.yaml.tftpl ]"
check "Packer configuration" "[ -f packer/ubuntu-hardened/ubuntu-hardened.pkr.hcl ]"
check "Ansible playbook" "[ -f ansible-playbooks/nexus.yml ]"
check "Ansible config" "[ -f ansible-playbooks/ansible.cfg ]"
check "Webhook callback plugin" "[ -f ansible-playbooks/plugins/callback/status_webhook.py ]"
check "Webhook receiver" "[ -f scripts/webhook-receiver/webhook_receiver.py ]"

echo ""
echo -e "${BLUE}[6/6] Git Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check "Git repository initialized" "[ -d .git ]"
check "Git user.name configured" "git config user.name"
check "Git user.email configured" "git config user.email"

if git remote -v | grep -q origin; then
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "none")
    echo -e "${GREEN}✓${NC} Git remote 'origin' configured: $REMOTE_URL"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}‼${NC} Git remote 'origin' not configured"
    echo "  You'll need to add this before pushing: git remote add origin <URL>"
    ((CHECKS_WARNED++))
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Summary ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "Passed: ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Failed: ${RED}$CHECKS_FAILED${NC}"
echo -e "Warnings: ${YELLOW}$CHECKS_WARNED${NC}"

echo ""

# Restore set -e before final exit check
set -e

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo " 1. Review IMPLEMENTATION_CHECKLIST.md"
    echo " 2. Start with Phase 1: Build golden image"
    echo " 3. Read docs/phase1-poc.md for detailed guide"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some critical checks failed${NC}"
    echo ""
    echo "Please resolve the failed checks before proceeding."
    echo ""

    if [ $CHECKS_WARNED -gt 0 ]; then
        echo -e "${YELLOW}Note: Warnings are non-critical but should be addressed.${NC}"
        echo ""
    fi

    exit 1
fi

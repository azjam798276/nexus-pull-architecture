#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check function (copied from preflight-check.sh)
check() {
    local name="$1"
    local command="$2"
    local severity="${3:-error}" # error or warn

    printf "%-50s " "Checking $name..."

    # Add debug output before eval
    echo "DEBUG: Running command: [$command]"

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        # Add debug output on failure
        echo "DEBUG: Command failed with exit code $?"
        if [ "$severity" = "error" ]; then
            echo -e "${RED}✗${NC}"
        else
            echo -e "${YELLOW}‼${NC}"
        fi
        return 1
    fi
}

# The specific check we are testing
check "OpenTofu installed" "command -v tofu"

echo "Test script finished."

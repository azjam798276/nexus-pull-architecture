"""
Custom Ansible callback plugin for webhook-based status reporting.
Sends playbook execution results to a configured HTTP endpoint.
"""

from ansible.plugins.callback import CallbackBase
import os
import json
try:
import requests
HAS_REQUESTS = True
except ImportError:
HAS_REQUESTS = False


class CallbackModule(CallbackBase):
"""
Callback plugin to send playbook stats to a webhook endpoint.
"""
CALLBACK_VERSION = 2.0
CALLBACK_TYPE = 'notification'
CALLBACK_NAME = 'status_webhook'
CALLBACK_NEEDS_ENABLED = True

def __init__(self):
super(CallbackModule, self).__init__()

# Get webhook URL from environment or ansible variable
self.webhook_url = os.getenv(
'ANSIBLE_WEBHOOK_URL',
'http://localhost:9191/webhook'
)

if not HAS_REQUESTS:
self._display.warning(
"status_webhook callback requires 'requests' library. "
"Install with: pip install requests"
)
self.disabled = True

def v2_playbook_on_stats(self, stats):
"""
Called when playbook execution completes.
Sends aggregated stats to webhook endpoint.
"""
if self.disabled:
return

# Get all hosts that were processed
hosts = sorted(stats.processed.keys())

if not hosts:
self._display.warning("No hosts found in stats")
return

# Build summary for each host
summary = {}
overall_status = 'success'

for host in hosts:
host_stats = stats.summarize(host)
summary[host] = host_stats

# Determine if this host had failures
if host_stats.get('failures', 0) > 0 or host_stats.get('unreachable', 0) > 0:
overall_status = 'failed'

# Build webhook payload
payload = {
'status': overall_status,
'hosts': hosts,
'summary': summary,
'playbook': self._playbook_name if hasattr(self, '_playbook_name') else 'unknown',
}

# Send to webhook
try:
response = requests.post(
self.webhook_url,
data=json.dumps(payload),
headers={'Content-Type': 'application/json'},
timeout=10
)

if response.status_code >= 200 and response.status_code < 300:
self._display.display(
f"Status webhook delivered successfully to {self.webhook_url}",
color='green'
)
else:
self._display.warning(
f"Webhook returned status {response.status_code}: {response.text}"
)

except requests.exceptions.RequestException as e:
self._display.warning(f"Failed to send webhook: {str(e)}")

def v2_playbook_on_start(self, playbook):
"""Capture playbook name for inclusion in webhook."""
self._playbook_name = os.path.basename(playbook._file_name)

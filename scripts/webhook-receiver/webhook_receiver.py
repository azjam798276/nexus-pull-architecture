#!/usr/bin/env python3
"""
Lightweight webhook receiver for Ansible pull status updates.
Receives JSON payloads from ansible-pull VMs and logs them.
"""

from fastapi import FastAPI, Request, Response, status
from fastapi.responses import JSONResponse
import logging
import json
from datetime import datetime
from typing import Dict, Any

# Configure logging
logging.basicConfig(
level=logging.INFO,
format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
handlers=[
logging.FileHandler('/var/log/ansible-webhook.log'),
logging.StreamHandler()
]
)

logger = logging.getLogger(__name__)

app = FastAPI(
title="Ansible Pull Webhook Receiver",
description="Receives and logs ansible-pull execution status",
version="1.0.0"
)

# In-memory store for recent statuses (last 100)
status_history: list[Dict[str, Any]] = []
MAX_HISTORY = 100


@app.get("/", response_class=JSONResponse)
async def root():
"""Health check endpoint."""
return {
"service": "ansible-webhook-receiver",
"status": "healthy",
"received_count": len(status_history)
}


@app.get("/status", response_class=JSONResponse)
async def get_status():
"""Return recent status updates."""
return {
"history_count": len(status_history),
"recent_updates": status_history[-10:] # Last 10
}


@app.post("/webhook", status_code=status.HTTP_204_NO_CONTENT)
async def receive_webhook(request: Request):
"""
Receive ansible-pull status webhook.

Expected payload:
{
"status": "success" | "failed",
"hosts": ["localhost"],
"summary": {...},
"playbook": "nexus.yml"
}
"""
try:
# Parse JSON payload
data = await request.json()

# Add timestamp
data['timestamp'] = datetime.utcnow().isoformat()
data['client_ip'] = request.client.host

# Log the status
log_level = logging.INFO if data.get('status') == 'success' else logging.ERROR
logger.log(
log_level,
f"Ansible pull status from {data.get('client_ip')}: "
f"{data.get('status')} - Playbook: {data.get('playbook')} - "
f"Summary: {json.dumps(data.get('summary'))}"
)

# Store in history
status_history.append(data)
if len(status_history) > MAX_HISTORY:
status_history.pop(0)

# Here you could add integration with monitoring systems:
# - Send to Prometheus pushgateway
# - Write to InfluxDB
# - Forward to Splunk/ELK
# - Trigger alerts for failures

return Response(status_code=status.HTTP_204_NO_CONTENT)

except json.JSONDecodeError as e:
logger.error(f"Invalid JSON payload: {e}")
return JSONResponse(
status_code=status.HTTP_400_BAD_REQUEST,
content={"error": "Invalid JSON payload"}
)
except Exception as e:
logger.error(f"Error processing webhook: {e}")
return JSONResponse(
status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
content={"error": "Internal server error"}
)


@app.on_event("startup")
async def startup_event():
logger.info("Webhook receiver started and listening...")


@app.on_event("shutdown")
async def shutdown_event():
logger.info("Webhook receiver shutting down...")


if __name__ == "__main__":
import uvicorn
uvicorn.run(
app,
host="0.0.0.0",
port=9191,
log_level="info"
)

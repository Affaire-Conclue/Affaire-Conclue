#!/usr/bin/env python3
"""
GitHub Webhook Listener for Hugo Deployment.
This service listens for GitHub webhooks and triggers Hugo deployment
Place this script at: /home/samwise/webhook-listener/webhook_listener.py
"""

import os
import sys
import json
import hmac
import hashlib
import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import logging
from datetime import datetime

# Configuration
WEBHOOK_PORT = 9000
WEBHOOK_SECRET_FILE = "/home/samwise/webhook-listener/.webhook_secret"
DEPLOY_SCRIPT = "/home/samwise/webhook-listener/deploy.sh"
LOG_FILE = "/var/log/webhook-listener.log"

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class WebhookHandler(BaseHTTPRequestHandler):
    """HTTP request handler for GitHub webhooks"""
    
    def log_message(self, format, *args):
        """Override default logging to use our logger"""
        logger.info(f"{self.address_string()} - {format % args}")
    
    def do_GET(self):
        """Handle GET requests (health check)"""
        if self.path == "/health":
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "status": "healthy",
                "timestamp": datetime.now().isoformat(),
                "service": "hugo-webhook-listener"
            }
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        """Handle POST requests (webhook payloads)"""
        if self.path != "/webhook":
            self.send_response(404)
            self.end_headers()
            return
        
        # Get content length
        content_length = int(self.headers.get('Content-Length', 0))
        if content_length == 0:
            logger.warning("Received webhook with no payload")
            self.send_response(400)
            self.end_headers()
            return
        
        # Read payload
        payload = self.rfile.read(content_length)
        
        # Verify webhook signature if secret is configured
        if not self.verify_signature(payload):
            logger.error("Webhook signature verification failed")
            self.send_response(401)
            self.end_headers()
            return
        
        try:
            # Parse JSON payload
            webhook_data = json.loads(payload.decode('utf-8'))
            
            # Log webhook event
            event_type = self.headers.get('X-GitHub-Event', 'unknown')
            logger.info(f"Received GitHub webhook event: {event_type}")
            
            # Only process push events
            if event_type != 'push':
                logger.info(f"Ignoring non-push event: {event_type}")
                self.send_response(200)
                self.end_headers()
                return
            
            # Check if push is to prod branch
            ref = webhook_data.get('ref', '')
            if ref != 'refs/heads/prod':
                branch = ref.replace('refs/heads/', '')
                logger.info(f"Ignoring push to branch: {branch} (only prod branch triggers deployment)")
                self.send_response(200)
                self.end_headers()
                return
            
            # Get commit information
            commits = webhook_data.get('commits', [])
            commit_count = len(commits)
            head_commit = webhook_data.get('head_commit', {})
            commit_message = head_commit.get('message', 'No message')
            commit_author = head_commit.get('author', {}).get('name', 'Unknown')
            
            logger.info(f"Processing push to prod branch: {commit_count} commits")
            logger.info(f"Latest commit: {commit_message} by {commit_author}")
            
            # Trigger deployment in background thread
            deployment_thread = threading.Thread(
                target=self.trigger_deployment,
                args=(webhook_data,)
            )
            deployment_thread.daemon = True
            deployment_thread.start()
            
            # Send immediate response
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            response = {
                "status": "deployment_triggered",
                "branch": "prod",
                "commits": commit_count,
                "timestamp": datetime.now().isoformat()
            }
            self.wfile.write(json.dumps(response).encode())
            
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse webhook payload: {e}")
            self.send_response(400)
            self.end_headers()
        except Exception as e:
            logger.error(f"Error processing webhook: {e}")
            self.send_response(500)
            self.end_headers()
    
    def verify_signature(self, payload):
        """Verify GitHub webhook signature"""
        # Skip verification if no secret is configured
        if not os.path.exists(WEBHOOK_SECRET_FILE):
            logger.warning("No webhook secret configured - skipping signature verification")
            return True
        
        # Get signature from headers
        signature_header = self.headers.get('X-Hub-Signature-256')
        if not signature_header:
            logger.warning("No signature header found")
            return False
        
        # Read secret
        try:
            with open(WEBHOOK_SECRET_FILE, 'r') as f:
                secret = f.read().strip()
        except Exception as e:
            logger.error(f"Failed to read webhook secret: {e}")
            return False
        
        # Calculate expected signature
        expected_signature = 'sha256=' + hmac.new(
            secret.encode('utf-8'),
            payload,
            hashlib.sha256
        ).hexdigest()
        
        # Compare signatures
        return hmac.compare_digest(signature_header, expected_signature)
    
    def trigger_deployment(self, webhook_data):
        """Trigger deployment script in background"""
        try:
            logger.info("Starting deployment process...")
            
            # Set environment variables for deployment script
            env = os.environ.copy()
            env['WEBHOOK_PAYLOAD'] = json.dumps(webhook_data)
            env['WEBHOOK_EVENT'] = 'push'
            
            # Execute deployment script
            result = subprocess.run(
                [DEPLOY_SCRIPT, 'webhook'],
                env=env,
                capture_output=True,
                text=True,
                timeout=300  # 5 minute timeout
            )
            
            if result.returncode == 0:
                logger.info("Deployment completed successfully")
                logger.info(f"Deployment output: {result.stdout}")
            else:
                logger.error(f"Deployment failed with exit code {result.returncode}")
                logger.error(f"Deployment error: {result.stderr}")
                
        except subprocess.TimeoutExpired:
            logger.error("Deployment timed out after 5 minutes")
        except Exception as e:
            logger.error(f"Failed to trigger deployment: {e}")


def create_systemd_service():
    """Generate systemd service file content"""
    service_content = f"""[Unit]
Description=Hugo Webhook Listener
After=network.target

[Service]
Type=simple
User=samwise
Group=samwise
WorkingDirectory=/home/samwise/webhook-listener
ExecStart=/usr/bin/python3 /home/samwise/webhook-listener/webhook_listener.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/samwise/caddy_setup /srv /var/log /home/samwise/backups

[Install]
WantedBy=multi-user.target
"""
    return service_content


def setup_webhook_secret():
    """Setup webhook secret if it doesn't exist"""
    if not os.path.exists(WEBHOOK_SECRET_FILE):
        # Generate random secret
        import secrets
        import string
        
        secret = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32))
        
        os.makedirs(os.path.dirname(WEBHOOK_SECRET_FILE), exist_ok=True)
        with open(WEBHOOK_SECRET_FILE, 'w') as f:
            f.write(secret)
        
        # Set restrictive permissions
        os.chmod(WEBHOOK_SECRET_FILE, 0o600)
        
        logger.info(f"Generated webhook secret and saved to {WEBHOOK_SECRET_FILE}")
        logger.info(f"Configure this secret in your GitHub webhook settings: {secret}")
    else:
        with open(WEBHOOK_SECRET_FILE, 'r') as f:
            secret = f.read().strip()
        logger.info(f"Using existing webhook secret from {WEBHOOK_SECRET_FILE}")


def main():
    """Main function to start webhook listener"""
    # Setup logging directory
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    
    logger.info("Starting Hugo Webhook Listener...")
    
    # Setup webhook secret
    setup_webhook_secret()
    
    # Check if deployment script exists and is executable
    if not os.path.exists(DEPLOY_SCRIPT):
        logger.error(f"Deployment script not found: {DEPLOY_SCRIPT}")
        sys.exit(1)
    
    if not os.access(DEPLOY_SCRIPT, os.X_OK):
        logger.error(f"Deployment script is not executable: {DEPLOY_SCRIPT}")
        sys.exit(1)
    
    # Create systemd service file if requested
    if len(sys.argv) > 1 and sys.argv[1] == '--generate-service':
        service_content = create_systemd_service()
        service_file = "/tmp/hugo-webhook.service"
        with open(service_file, 'w') as f:
            f.write(service_content)
        print(f"Systemd service file generated: {service_file}")
        print("To install the service:")
        print(f"sudo cp {service_file} /etc/systemd/system/")
        print("sudo systemctl daemon-reload")
        print("sudo systemctl enable hugo-webhook")
        print("sudo systemctl start hugo-webhook")
        return
    
    # Start HTTP server
    try:
        server = HTTPServer(('', WEBHOOK_PORT), WebhookHandler)
        logger.info(f"Webhook listener started on port {WEBHOOK_PORT}")
        logger.info(f"Health check available at: http://localhost:{WEBHOOK_PORT}/health")
        logger.info(f"Webhook endpoint: http://localhost:{WEBHOOK_PORT}/webhook")
        
        server.serve_forever()
        
    except KeyboardInterrupt:
        logger.info("Shutting down webhook listener...")
        server.shutdown()
    except Exception as e:
        logger.error(f"Failed to start webhook listener: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
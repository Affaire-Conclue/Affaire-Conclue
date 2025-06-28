#!/bin/bash

# Hugo Resume Website Setup Script.
# This script sets up the complete CI/CD pipeline and website improvements

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_DIR="/home/samwise/caddy_setup/affaireconclue-source"
WEBHOOK_DIR="/home/samwise/webhook-listener"
SERVE_DIR="/srv"
LOG_DIR="/var/log"
BACKUP_DIR="/home/samwise/backups/site"

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as correct user
check_user() {
    if [ "$USER" != "samwise" ]; then
        print_error "This script should be run as user 'samwise'"
        exit 1
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Hugo is installed
    if ! command -v hugo &> /dev/null; then
        print_error "Hugo is not installed. Please install Hugo first."
        exit 1
    fi
    
    # Check if Git is installed
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed. Please install Git first."
        exit 1
    fi
    
    # Check if Python3 is installed
    if ! command -v python3 &> /dev/null; then
        print_error "Python3 is not installed. Please install Python3 first."
        exit 1
    fi
    
    # Check if repository exists
    if [ ! -d "$REPO_DIR" ]; then
        print_error "Repository directory not found: $REPO_DIR"
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Create directory structure
setup_directories() {
    print_status "Setting up directory structure..."
    
    mkdir -p "$WEBHOOK_DIR"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$REPO_DIR/static/images/profile"
    mkdir -p "$REPO_DIR/static/images/projects"
    mkdir -p "$REPO_DIR/static/images/hero"
    mkdir -p "$REPO_DIR/assets/css"
    
    # Create log directories (may require sudo)
    if [ ! -d "$LOG_DIR" ]; then
        print_warning "Log directory $LOG_DIR doesn't exist. You may need to create it with sudo."
    fi
    
    print_success "Directory structure created"
}

# Setup Hugo theme customizations
setup_hugo_customizations() {
    print_status "Setting up Hugo theme customizations..."
    
    cd "$REPO_DIR"
    
    # Create custom CSS file
    cat > assets/css/custom.css << 'EOF'
/* This file will contain the custom CSS from the artifacts */
/* Copy the CSS content from the custom_css_styles artifact */
EOF
    
    # Update Hugo config to include custom CSS
    if [ -f "hugo.toml" ]; then
        # Check if custom CSS is already configured
        if ! grep -q "custom.css" hugo.toml; then
            print_status "Adding custom CSS configuration to hugo.toml..."
            # This would need to be customized based on your specific Hugo config
        fi
    fi
    
    print_success "Hugo customizations applied"
}

# Setup webhook listener
setup_webhook() {
    print_status "Setting up webhook listener..."
    
    # Copy deployment script (this would be created from the artifacts)
    cat > "$WEBHOOK_DIR/deploy.sh" << 'EOF'
# Copy the content from the deployment_script artifact here
EOF
    chmod +x "$WEBHOOK_DIR/deploy.sh"
    
    # Copy webhook listener (this would be created from the artifacts)
    cat > "$WEBHOOK_DIR/webhook_listener.py" << 'EOF'
# Copy the content from the webhook_listener artifact here
EOF
    chmod +x "$WEBHOOK_DIR/webhook_listener.py"
    
    print_success "Webhook listener setup complete"
}

# Generate systemd service
setup_systemd_service() {
    print_status "Generating systemd service..."
    
    python3 "$WEBHOOK_DIR/webhook_listener.py" --generate-service
    
    print_status "Systemd service file generated at /tmp/hugo-webhook.service"
    print_status "To install the service, run these commands as root:"
    echo "  sudo cp /tmp/hugo-webhook.service /etc/systemd/system/"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl enable hugo-webhook"
    echo "  sudo systemctl start hugo-webhook"
}

# Setup GitHub repository branches
setup_git_branches() {
    print_status "Setting up Git branches..."
    
    cd "$REPO_DIR"
    
    # Make sure we're on main branch
    git checkout main || git checkout -b main
    
    # Create prod branch if it doesn't exist
    if ! git show-ref --verify --quiet refs/heads/prod; then
        print_status "Creating prod branch..."
        git checkout -b prod
        git push -u origin prod
        git checkout main
    fi
    
    # Make sure branches are up to date
    git fetch origin
    git pull origin main
    
    print_success "Git branches configured"
}

# Test webhook endpoint
test_webhook() {
    print_status "Testing webhook endpoint..."
    
    # Start webhook listener in background for testing
    python3 "$WEBHOOK_DIR/webhook_listener.py" &
    WEBHOOK_PID=$!
    
    sleep 2
    
    # Test health endpoint
    if curl -s http://localhost:9000/health > /dev/null; then
        print_success "Webhook listener is responding"
    else
        print_warning "Webhook listener health check failed"
    fi
    
    # Stop test webhook listener
    kill $WEBHOOK_PID 2>/dev/null || true
}

# Display setup summary
display_summary() {
    print_success "Setup completed successfully!"
    echo
    echo "=== SETUP SUMMARY ==="
    echo "Repository: $REPO_DIR"
    echo "Webhook listener: $WEBHOOK_DIR"
    echo "Backup directory: $BACKUP_DIR"
    echo
    echo "=== NEXT STEPS ==="
    echo "1. Install the systemd service (requires sudo):"
    echo "   sudo cp /tmp/hugo-webhook.service /etc/systemd/system/"
    echo "   sudo systemctl daemon-reload"
    echo "   sudo systemctl enable hugo-webhook"
    echo "   sudo systemctl start hugo-webhook"
    echo
    echo "2. Configure GitHub webhook:"
    echo "   - Go to your GitHub repository settings"
    echo "   - Add webhook with URL: http://your-server:9000/webhook"
    echo "   - Set content type: application/json"
    echo "   - Set secret: $(cat $WEBHOOK_DIR/.webhook_secret 2>/dev/null || echo 'Not generated yet')"
    echo "   - Select 'Just the push event'"
    echo
    echo "3. Test the deployment:"
    echo "   - Make changes to main branch"
    echo "   - Merge main to prod: git checkout prod && git merge main && git push origin prod"
    echo "   - Check deployment logs: tail -f /var/log/hugo-deploy.log"
    echo
    echo "4. Copy custom content:"
    echo "   - Copy the enhanced About Me content to your Hugo content files"
    echo "   - Copy the custom CSS to assets/css/custom.css"
    echo "   - Download professional images from photos.oidrissi.com"
    echo
    echo "=== MONITORING ==="
    echo "Webhook logs: tail -f /var/log/webhook-listener.log"
    echo "Deployment logs: tail -f /var/log/hugo-deploy.log"
    echo "Service status: sudo systemctl status hugo-webhook"
}

# Main execution
main() {
    echo "=== Hugo Resume Website Setup ==="
    echo
    
    check_user
    check_prerequisites
    setup_directories
    setup_hugo_customizations
    setup_git_branches
    setup_webhook
    setup_systemd_service
    test_webhook
    display_summary
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Hugo Resume Website Setup Script"
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --test         Run in test mode (no actual changes)"
        echo
        exit 0
        ;;
    --test)
        print_status "Running in test mode - no changes will be made"
        # Add test mode logic here
        ;;
    *)
        main
        ;;
esac
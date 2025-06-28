#!/bin/bash

# Hugo Resume Website Auto-Deployment Script
# This script handles automated deployment from GitHub prod branch
# Place this script at: /home/samwise/webhook-listener/deploy.sh

set -e  # Exit on any error

# Configuration
REPO_DIR="/home/samwise/caddy_setup/affaireconclue-source"
BUILD_DIR="/home/samwise/caddy_setup/site"
SERVE_DIR="/srv"
LOG_FILE="/var/log/hugo-deploy.log"
BACKUP_DIR="/home/samwise/backups/site"
WEBHOOK_SECRET_FILE="/home/samwise/webhook-listener/.webhook_secret"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Error handling function
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Create necessary directories
create_directories() {
    log "Creating necessary directories..."
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$BUILD_DIR"
    touch "$LOG_FILE"
}

# Backup current site
backup_current_site() {
    if [ -d "$SERVE_DIR" ] && [ "$(ls -A $SERVE_DIR 2>/dev/null)" ]; then
        log "Creating backup of current site..."
        BACKUP_NAME="site_backup_$(date +%Y%m%d_%H%M%S)"
        cp -r "$SERVE_DIR" "$BACKUP_DIR/$BACKUP_NAME" || error_exit "Failed to create backup"
        log "Backup created: $BACKUP_DIR/$BACKUP_NAME"
        
        # Keep only last 5 backups
        cd "$BACKUP_DIR"
        ls -t | tail -n +6 | xargs -r rm -rf
        log "Old backups cleaned up"
    fi
}

# Validate repository directory
validate_repo() {
    if [ ! -d "$REPO_DIR" ]; then
        error_exit "Repository directory not found: $REPO_DIR"
    fi
    
    if [ ! -d "$REPO_DIR/.git" ]; then
        error_exit "Not a git repository: $REPO_DIR"
    fi
}

# Update repository from GitHub
update_repository() {
    log "Updating repository from GitHub..."
    cd "$REPO_DIR" || error_exit "Cannot change to repository directory"
    
    # Stash any local changes
    git stash push -m "Auto-stash before deployment $(date)" || true
    
    # Fetch latest changes
    git fetch origin || error_exit "Failed to fetch from origin"
    
    # Switch to prod branch
    git checkout prod || error_exit "Failed to checkout prod branch"
    
    # Get current commit hash before pull
    OLD_COMMIT=$(git rev-parse HEAD)
    
    # Pull latest changes
    git pull origin prod || error_exit "Failed to pull from prod branch"
    
    # Get new commit hash after pull
    NEW_COMMIT=$(git rev-parse HEAD)
    
    log "Repository updated successfully"
    log "Previous commit: $OLD_COMMIT"
    log "Current commit: $NEW_COMMIT"
    
    # Check if there are actually new changes
    if [ "$OLD_COMMIT" = "$NEW_COMMIT" ]; then
        log "No new changes detected, skipping build"
        return 1
    fi
    
    return 0
}

# Build Hugo site
build_site() {
    log "Building Hugo site..."
    cd "$REPO_DIR" || error_exit "Cannot change to repository directory"
    
    # Clean build directory
    rm -rf "$BUILD_DIR"/*
    
    # Check if Hugo is installed
    if ! command -v hugo &> /dev/null; then
        error_exit "Hugo is not installed or not in PATH"
    fi
    
    # Build the site
    hugo --destination "$BUILD_DIR" --minify || error_exit "Hugo build failed"
    
    # Verify build output exists
    if [ ! -d "$BUILD_DIR" ] || [ -z "$(ls -A $BUILD_DIR 2>/dev/null)" ]; then
        error_exit "Build output directory is empty"
    fi
    
    log "Hugo site built successfully"
}

# Deploy to production directory
deploy_site() {
    log "Deploying site to production directory..."
    
    # Create serving directory if it doesn't exist
    mkdir -p "$SERVE_DIR"
    
    # Copy built site to serving directory
    rsync -av --delete "$BUILD_DIR/" "$SERVE_DIR/" || error_exit "Failed to copy site to serving directory"
    
    # Set proper permissions
    find "$SERVE_DIR" -type f -exec chmod 644 {} \;
    find "$SERVE_DIR" -type d -exec chmod 755 {} \;
    
    log "Site deployed successfully to $SERVE_DIR"
}

# Send notification (optional - requires mail or other notification service)
send_notification() {
    local status=$1
    local message=$2
    
    # Example using mail command (install mailutils if needed)
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "Hugo Deployment $status" "your-email@domain.com" 2>/dev/null || true
    fi
    
    # Example using curl to send to Slack webhook (replace with your webhook URL)
    # if [ -n "$SLACK_WEBHOOK_URL" ]; then
    #     curl -X POST -H 'Content-type: application/json' \
    #         --data "{\"text\":\"Hugo Deployment $status: $message\"}" \
    #         "$SLACK_WEBHOOK_URL" || true
    # fi
}

# Rollback function in case of failure
rollback() {
    log "Rolling back to previous version..."
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -n 1)
    if [ -n "$LATEST_BACKUP" ] && [ -d "$BACKUP_DIR/$LATEST_BACKUP" ]; then
        cp -r "$BACKUP_DIR/$LATEST_BACKUP/"* "$SERVE_DIR/"
        log "Rollback completed using backup: $LATEST_BACKUP"
        send_notification "ROLLBACK" "Site rolled back to previous version due to deployment failure"
    else
        log "No backup available for rollback"
    fi
}

# Health check function
health_check() {
    log "Performing health check..."
    
    # Check if index.html exists
    if [ ! -f "$SERVE_DIR/index.html" ]; then
        error_exit "Health check failed: index.html not found"
    fi
    
    # Check if basic files exist
    local required_files=("index.html")
    for file in "${required_files[@]}"; do
        if [ ! -f "$SERVE_DIR/$file" ]; then
            error_exit "Health check failed: Required file $file not found"
        fi
    done
    
    log "Health check passed"
}

# Main deployment function
main() {
    log "=== Starting Hugo deployment process ==="
    
    # Trap errors for rollback
    trap 'rollback; exit 1' ERR
    
    create_directories
    validate_repo
    backup_current_site
    
    # Update repository and check for changes
    if ! update_repository; then
        log "=== No deployment needed - no new changes ==="
        exit 0
    fi
    
    build_site
    deploy_site
    health_check
    
    # Disable error trap - deployment successful
    trap - ERR
    
    log "=== Deployment completed successfully ==="
    send_notification "SUCCESS" "Hugo site deployed successfully"
}

# Webhook handler mode (when called with webhook payload)
webhook_handler() {
    log "=== Webhook deployment triggered ==="
    
    # Basic security check (verify webhook secret if configured)
    if [ -f "$WEBHOOK_SECRET_FILE" ]; then
        EXPECTED_SECRET=$(cat "$WEBHOOK_SECRET_FILE")
        if [ -n "$WEBHOOK_SECRET" ] && [ "$WEBHOOK_SECRET" != "$EXPECTED_SECRET" ]; then
            log "ERROR: Invalid webhook secret"
            exit 1
        fi
    fi
    
    # Parse webhook payload to check if it's for prod branch
    if [ -n "$WEBHOOK_PAYLOAD" ]; then
        BRANCH=$(echo "$WEBHOOK_PAYLOAD" | grep -o '"ref":"refs/heads/[^"]*"' | cut -d'/' -f3 | tr -d '"' || echo "unknown")
        if [ "$BRANCH" != "prod" ]; then
            log "Webhook for branch '$BRANCH' - ignoring (only prod branch triggers deployment)"
            exit 0
        fi
    fi
    
    main
}

# Check if running in webhook mode
if [ "$1" = "webhook" ]; then
    webhook_handler
else
    main
fi
#!/bin/bash

# WordPress Backup Tool for WP Engine
# Creates backups of WordPress content via SSH

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Validate environment variables
validate_env_vars() {
    local missing_vars=()
    
    [[ -z "${SSH_USER:-}" ]] && missing_vars+=("SSH_USER")
    [[ -z "${SSH_HOST:-}" ]] && missing_vars+=("SSH_HOST")
    [[ -z "${SSH_PATH:-}" ]] && missing_vars+=("SSH_PATH")
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error "Missing required environment variables: ${missing_vars[*]}"
        exit 1
    fi
    
    log "Environment variables validated successfully"
}

# Create backup filename with current date
create_backup_filename() {
    BACKUP_DATE=$(date +'%Y-%m-%d')
    BACKUP_FILENAME="${BACKUP_DATE}.wp-content.zip"
    log "Backup filename: $BACKUP_FILENAME"
}

# Setup SSH key if provided
setup_ssh_key() {
    if [[ -n "${SSH_PUBLIC_KEY:-}" ]]; then
        SSH_KEY_FILE=$(mktemp)
        echo "$SSH_PUBLIC_KEY" > "$SSH_KEY_FILE"
        chmod 600 "$SSH_KEY_FILE"
        SSH_OPTS="-i $SSH_KEY_FILE"
        log "SSH key configured"
    else
        SSH_OPTS=""
        log "Using password authentication"
    fi
}

# Create backup on remote server
create_remote_backup() {
    log "Creating backup on remote server..."
    
    # Create zip command for wp-content and important files
    local zip_command="cd $SSH_PATH && zip -r $BACKUP_FILENAME \
        wp-content/uploads/ \
        wp-content/themes/ \
        wp-content/plugins/ \
        wp-config.php \
        -x 'wp-content/cache/*' 'wp-content/tmp/*' \
        || echo 'Some files may have been skipped due to permissions'"
    
    if ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "$zip_command"; then
        log "Backup created successfully on remote server"
    else
        error "Failed to create backup on remote server"
        cleanup_and_exit 1
    fi
}

# Download backup to local home directory
download_backup() {
    log "Downloading backup to home directory..."
    
    local remote_path="$SSH_USER@$SSH_HOST:$SSH_PATH/$BACKUP_FILENAME"
    local local_path="$HOME/$BACKUP_FILENAME"
    
    if scp $SSH_OPTS "$remote_path" "$local_path"; then
        local file_size=$(du -h "$local_path" | cut -f1)
        log "Backup downloaded successfully to $local_path (Size: $file_size)"
    else
        error "Failed to download backup"
        cleanup_and_exit 1
    fi
}

# Clean up remote backup file
cleanup_remote_backup() {
    log "Cleaning up remote backup file..."
    
    if ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "rm -f $SSH_PATH/$BACKUP_FILENAME"; then
        log "Remote backup file cleaned up"
    else
        warning "Failed to clean up remote backup file"
    fi
}

# Cleanup function
cleanup_and_exit() {
    local exit_code=${1:-0}
    
    # Clean up temporary SSH key file
    if [[ -n "${SSH_KEY_FILE:-}" ]] && [[ -f "$SSH_KEY_FILE" ]]; then
        rm -f "$SSH_KEY_FILE"
        log "Temporary SSH key file cleaned up"
    fi
    
    exit $exit_code
}

# Main function
main() {
    log "Starting WordPress backup process..."
    
    # Validate environment variables
    validate_env_vars
    
    # Create backup filename
    create_backup_filename
    
    # Setup SSH key
    setup_ssh_key
    
    # Trap to ensure cleanup on exit
    trap 'cleanup_and_exit $?' EXIT
    
    # Create backup on remote server
    create_remote_backup
    
    # Download backup to local machine
    download_backup
    
    # Clean up remote backup file
    cleanup_remote_backup
    
    log "Backup process completed successfully!"
}

# Run main function
main "$@"
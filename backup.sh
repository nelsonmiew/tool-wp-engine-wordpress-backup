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
    
    # Set default backup folders if not specified
    if [[ -z "${WP_BACKUP_INCLUDE_ONLY_FOLDERS:-}" ]]; then
        WP_BACKUP_INCLUDE_ONLY_FOLDERS="uploads,languages"
        log "Using default backup folders: $WP_BACKUP_INCLUDE_ONLY_FOLDERS"
    else
        log "Using specified backup folders: $WP_BACKUP_INCLUDE_ONLY_FOLDERS"
    fi

    # Set default backup destination if not specified
    if [[ -z "${BACKUP_DEST:-}" ]]; then
        BACKUP_DEST="~"
        log "Using default backup destination: $BACKUP_DEST"
    else
        log "Using specified backup destination: $BACKUP_DEST"
    fi

    log "Environment variables validated successfully"
}

# Create backup filename with current date
create_backup_filename() {
    BACKUP_DATE=$(date +'%Y-%m-%d')
    if [[ -n "${BACKUP_TAG:-}" ]]; then
        BACKUP_FILENAME="${BACKUP_DATE}.${BACKUP_TAG}.wp-content.zip"
        DB_BACKUP_FILENAME="${BACKUP_DATE}.${BACKUP_TAG}.database.zip"
    else
        BACKUP_FILENAME="${BACKUP_DATE}.wp-content.zip"
        DB_BACKUP_FILENAME="${BACKUP_DATE}.database.zip"
    fi
    log "Backup filename: $BACKUP_FILENAME"
    log "Database backup filename: $DB_BACKUP_FILENAME"
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

# Build folder paths from WP_BACKUP_INCLUDE_ONLY_FOLDERS
build_folder_paths() {
    local folder_paths=""
    IFS=',' read -ra FOLDERS <<< "$WP_BACKUP_INCLUDE_ONLY_FOLDERS"
    for folder in "${FOLDERS[@]}"; do
        # Trim whitespace
        folder=$(echo "$folder" | xargs)
        if [[ -n "$folder" ]]; then
            folder_paths="$folder_paths wp-content/$folder/"
        fi
    done

    if [[ -z "$folder_paths" ]]; then
        error "No valid folders specified for backup"
        cleanup_and_exit 1
    fi

    log "Backing up folders: $folder_paths"
    echo "$folder_paths"
}

# Ensure backup destination directory exists on remote server
ensure_remote_backup_directory() {
    log "Ensuring backup destination directory exists..."
    if ! ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "mkdir -p $BACKUP_DEST"; then
        error "Failed to create backup destination directory on remote server"
        cleanup_and_exit 1
    fi
}

# Verify backup destination path and create test file
verify_backup_destination() {
    log "Verifying backup destination path..."
    local test_file="${BACKUP_FILENAME}.location.txt"
    local remote_abs_path=$(ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "cd $BACKUP_DEST && pwd && echo 'Backup will be created at: \$(pwd)/$BACKUP_FILENAME' > $test_file && cat $test_file")

    if [[ -z "$remote_abs_path" ]]; then
        error "Failed to verify backup destination directory"
        cleanup_and_exit 1
    fi

    echo "$remote_abs_path"
    echo ""
    echo "$remote_abs_path"
}

# Create zip backup on remote server
create_zip_backup() {
    local folder_paths="$1"
    local remote_abs_path="$2"

    # Create zip command for specified wp-content folders in the destination directory
    # The backup path expansion happens on the remote server
    local zip_command="cd $SSH_PATH && zip -r $BACKUP_DEST/$BACKUP_FILENAME \
        $folder_paths \
        wp-config.php \
        wp-includes/version.php \
        -x 'wp-content/cache/*' 'wp-content/tmp/*' \
        || echo 'Some files may have been skipped due to permissions'"

    if ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "$zip_command"; then
        verify_backup_created "$remote_abs_path"
    else
        error "Failed to create backup on remote server"
        cleanup_and_exit 1
    fi
}

# Verify backup file was created successfully
verify_backup_created() {
    local remote_abs_path="$1"

    # Extract just the directory path from the verification output
    local backup_dir=$(echo "$remote_abs_path" | head -n1)
    local full_backup_path="${backup_dir}/${BACKUP_FILENAME}"

    # Check if the backup was actually created
    if ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "test -f $BACKUP_DEST/$BACKUP_FILENAME"; then
        log "Backup created successfully"
        echo ""
        echo -e "${GREEN}Backup file location:${NC} $SSH_USER@$SSH_HOST:$full_backup_path"
        echo ""
    else
        error "Backup file was not created on remote server"
        cleanup_and_exit 1
    fi
}

# Create backup on remote server
create_remote_backup() {
    log "Creating backup on remote server..."

    # Build folder paths
    local folder_paths=$(build_folder_paths)

    # Ensure backup destination exists
    ensure_remote_backup_directory

    # Verify backup destination path
    local remote_abs_path=$(verify_backup_destination)

    # Create the zip backup
    create_zip_backup "$folder_paths" "$remote_abs_path"
}


# Clean up test file on remote server
cleanup_remote_test_file() {
    if [[ -n "${BACKUP_FILENAME:-}" ]]; then
        local test_file="${BACKUP_FILENAME}.location.txt"
        if ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "test -f $BACKUP_DEST/$test_file" 2>/dev/null; then
            ssh $SSH_OPTS "$SSH_USER@$SSH_HOST" "rm -f $BACKUP_DEST/$test_file" 2>/dev/null || true
            log "Remote test file cleaned up"
        fi
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

    # Clean up test file on remote server
    cleanup_remote_test_file

    log "Backup process completed successfully!"
}

# Run main function
main "$@"
# WordPress Backup Tool for WP Engine

A lightweight shell script tool to create WordPress content backups via SSH. This tool connects to your WordPress server, creates a zip backup of important files and folders, and downloads it to your local machine with a date-based filename.

## Features

- 🔐 SSH connection with key or password authentication
- 📦 Automated zip backup creation
- 📁 Backs up wp-content/uploads, themes, plugins, and wp-config.php
- 📅 Date-based filename pattern: `YYYY-MM-DD.wp-content.zip`
- 🏠 Downloads backup to your home directory
- 🧹 Automatic cleanup of remote backup files
- 🚀 Lightweight shell script implementation

## Requirements

- SSH client
- SCP client
- zip/unzip utilities
- Bash shell

## Installation

1. Clone this repository:

```bash
git clone https://github.com/nelsonmiew/tool-wp-engine-wordpress-backup.git
cd tool-wp-engine-wordpress-backup
```

2. Make the script executable:

```bash
chmod +x backup.sh
```

## Configuration

Set the following environment variables:

### Required Variables:

- `SSH_USER`: SSH username for the remote server
- `SSH_HOST`: SSH hostname or IP address
- `SSH_PATH`: Path to WordPress installation on remote server

### Optional Variables:

- `SSH_PUBLIC_KEY`: SSH private key content (if not set, will use password auth)
- `SSH_MYSQL_PATH`: MySQL path (for future database backup features)
- `WP_BACKUP_INCLUDE_ONLY_FOLDERS`: Comma-separated list of folders within wp-content to backup (default: "uploads,languages")
- `BACKUP_DEST`: Destination path for backup files on the remote server (default: "~")
- `BACKUP_TAG`: Optional tag to include in backup filename (default: empty)

### Example:

```bash
export SSH_USER="your-username"
export SSH_HOST="your-server.com"
export SSH_PATH="/var/www/html/wordpress"
export SSH_PUBLIC_KEY="$(cat ~/.ssh/id_rsa)"
export WP_BACKUP_INCLUDE_ONLY_FOLDERS="uploads,languages"
export BACKUP_DEST="~"
export BACKUP_TAG="production"  # Optional
```

## Usage

Run the backup script:

```bash
./backup.sh
```

## What Gets Backed Up

The tool creates a zip file containing:

- Folders specified in `WP_BACKUP_INCLUDE_ONLY_FOLDERS` (default: uploads, languages)
  - `wp-content/uploads/` - All uploaded media files (default)
  - `wp-content/languages/` - WordPress language files (default)
- `wp-config.php` - WordPress configuration file
- `wp-includes/version.php` - WordPress version information

**Excluded from backup:**

- `wp-content/cache/` - Cache files
- `wp-content/tmp/` - Temporary files

You can customize which folders to backup by setting the `WP_BACKUP_INCLUDE_ONLY_FOLDERS` environment variable:

```bash
export WP_BACKUP_INCLUDE_ONLY_FOLDERS="uploads,themes,plugins"
```

## Output

The backup file will be saved to the destination specified by `BACKUP_DEST` (default: home directory) with the format:

```
~/YYYY-MM-DD.wp-content.zip
~/YYYY-MM-DD.tag.wp-content.zip  # If BACKUP_TAG is set
```

For example:
- `~/2024-01-15.wp-content.zip`
- `~/2024-01-15.production.wp-content.zip` (with BACKUP_TAG="production")

The script will display the backup file location upon completion.

## Security Notes

- SSH private keys are handled securely and cleaned up after use
- The tool uses standard SSH/SCP commands for secure connections
- Remote backup files are automatically deleted after download
- No credentials are stored permanently

## Troubleshooting

### Permission Errors

If you encounter permission errors, ensure your SSH user has read access to the WordPress directory and write access to create zip files.

### Connection Issues

- Verify SSH credentials and server accessibility
- Check that SSH service is running on the target server
- Ensure firewall allows SSH connections

### Missing Files in Backup

Some files may be skipped due to permissions. The tool will continue and report warnings for any inaccessible files.

## Contributing

Feel free to submit issues and enhancement requests!

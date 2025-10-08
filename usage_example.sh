#!/bin/bash

# Example usage script for WordPress Backup Tool
# This demonstrates how to use the backup tool

echo "WordPress Backup Tool - Usage Example"
echo "====================================="

echo ""
echo "1. Setting up environment variables:"
echo "export SSH_USER=\"your-username\""
echo "export SSH_HOST=\"your-server.com\""
echo "export SSH_PATH=\"/var/www/html/wordpress\""
echo "export SSH_PUBLIC_KEY=\"\$(cat ~/.ssh/id_rsa)\""
echo "export backup_include_only_folders=\"uploads,languages\""

echo ""
echo "2. Running the backup script:"
echo "./backup.sh"

echo ""
echo "3. Expected output files:"
echo "~/$(date +'%Y-%m-%d').wp-content.zip"

echo ""
echo "4. What gets backed up (customizable):"
echo "   - wp-content/uploads/ (default)"
echo "   - wp-content/languages/ (default)"
echo "   - wp-config.php (always included)"
echo "   - wp-includes/version.php (always included)"
echo ""
echo "5. Customize backup folders:"
echo "   export backup_include_only_folders=\"uploads,themes,plugins\""

echo ""
echo "6. Files excluded from backup:"
echo "   - wp-content/cache/ (cache files)"
echo "   - wp-content/tmp/ (temporary files)"

echo ""
echo "For more information, see README.md"
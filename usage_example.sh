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

echo ""
echo "2. Running the backup script:"
echo "./backup.sh"

echo ""
echo "3. Expected output files:"
echo "~/$(date +'%Y-%m-%d').wp-content.zip"

echo ""
echo "4. What gets backed up:"
echo "   - wp-content/uploads/ (all media files)"
echo "   - wp-content/themes/ (WordPress themes)"
echo "   - wp-content/plugins/ (WordPress plugins)"
echo "   - wp-config.php (WordPress configuration)"

echo ""
echo "5. Files excluded from backup:"
echo "   - wp-content/cache/ (cache files)"
echo "   - wp-content/tmp/ (temporary files)"

echo ""
echo "For more information, see README.md"
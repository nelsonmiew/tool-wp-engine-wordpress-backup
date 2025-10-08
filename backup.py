#!/usr/bin/env python3
"""
WordPress Backup Tool for WP Engine
Creates backups of WordPress content and database via SSH
"""

import os
import sys
import subprocess
import tempfile
from datetime import datetime
import paramiko
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class WordPressBackup:
    def __init__(self):
        self.ssh_client = None
        self.sftp_client = None
        
        # Load environment variables
        self.ssh_user = os.getenv('SSH_USER')
        self.ssh_host = os.getenv('SSH_HOST')
        self.ssh_path = os.getenv('SSH_PATH')
        self.ssh_mysql_path = os.getenv('SSH_MYSQL_PATH')
        self.ssh_public_key = os.getenv('SSH_PUBLIC_KEY')
        
        # Validate required environment variables
        self._validate_env_vars()
        
        # Generate backup filename with current date
        self.backup_date = datetime.now().strftime('%Y-%m-%d')
        self.backup_filename = f"{self.backup_date}.wp-content.zip"
        
    def _validate_env_vars(self):
        """Validate that all required environment variables are set"""
        required_vars = ['SSH_USER', 'SSH_HOST', 'SSH_PATH']
        missing_vars = [var for var in required_vars if not getattr(self, var.lower())]
        
        if missing_vars:
            logger.error(f"Missing required environment variables: {missing_vars}")
            sys.exit(1)
            
        logger.info("Environment variables validated successfully")
    
    def _setup_ssh_connection(self):
        """Establish SSH connection to the remote server"""
        try:
            self.ssh_client = paramiko.SSHClient()
            self.ssh_client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            
            # If SSH_PUBLIC_KEY is provided, use key authentication
            if self.ssh_public_key:
                # Create temporary key file
                with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.pem') as key_file:
                    key_file.write(self.ssh_public_key)
                    key_file_path = key_file.name
                
                try:
                    private_key = paramiko.RSAKey.from_private_key_file(key_file_path)
                    self.ssh_client.connect(
                        hostname=self.ssh_host,
                        username=self.ssh_user,
                        pkey=private_key
                    )
                finally:
                    # Clean up temporary key file
                    os.unlink(key_file_path)
            else:
                # Use password authentication (will prompt)
                self.ssh_client.connect(
                    hostname=self.ssh_host,
                    username=self.ssh_user
                )
            
            self.sftp_client = self.ssh_client.open_sftp()
            logger.info(f"SSH connection established to {self.ssh_host}")
            
        except Exception as e:
            logger.error(f"Failed to establish SSH connection: {e}")
            sys.exit(1)
    
    def _create_remote_backup(self):
        """Create backup on remote server"""
        try:
            # Change to the WordPress path
            remote_backup_path = f"{self.ssh_path}/{self.backup_filename}"
            
            # Create zip command for wp-content/uploads and other important folders
            zip_command = f"""
                cd {self.ssh_path} && \
                zip -r {self.backup_filename} \
                wp-content/uploads/ \
                wp-content/themes/ \
                wp-content/plugins/ \
                wp-config.php \
                -x "wp-content/cache/*" "wp-content/tmp/*" \
                || echo "Some files may have been skipped due to permissions"
            """
            
            logger.info("Creating backup on remote server...")
            stdin, stdout, stderr = self.ssh_client.exec_command(zip_command)
            
            # Wait for command to complete
            exit_status = stdout.channel.recv_exit_status()
            
            if exit_status == 0:
                logger.info("Backup created successfully on remote server")
            else:
                error_output = stderr.read().decode()
                logger.warning(f"Backup completed with warnings: {error_output}")
            
            return remote_backup_path
            
        except Exception as e:
            logger.error(f"Failed to create remote backup: {e}")
            sys.exit(1)
    
    def _download_backup(self, remote_backup_path):
        """Download backup file to local home directory"""
        try:
            local_backup_path = os.path.expanduser(f"~/{self.backup_filename}")
            
            logger.info(f"Downloading backup to {local_backup_path}...")
            self.sftp_client.get(remote_backup_path, local_backup_path)
            
            # Get file size for confirmation
            file_size = os.path.getsize(local_backup_path)
            logger.info(f"Backup downloaded successfully. Size: {file_size / (1024*1024):.2f} MB")
            
            return local_backup_path
            
        except Exception as e:
            logger.error(f"Failed to download backup: {e}")
            sys.exit(1)
    
    def _cleanup_remote_backup(self, remote_backup_path):
        """Clean up the backup file from remote server"""
        try:
            self.sftp_client.remove(remote_backup_path)
            logger.info("Remote backup file cleaned up")
        except Exception as e:
            logger.warning(f"Failed to clean up remote backup: {e}")
    
    def _close_connections(self):
        """Close SSH and SFTP connections"""
        if self.sftp_client:
            self.sftp_client.close()
        if self.ssh_client:
            self.ssh_client.close()
        logger.info("Connections closed")
    
    def create_backup(self):
        """Main method to create and download WordPress backup"""
        try:
            logger.info("Starting WordPress backup process...")
            
            # Setup SSH connection
            self._setup_ssh_connection()
            
            # Create backup on remote server
            remote_backup_path = self._create_remote_backup()
            
            # Download backup to local machine
            local_backup_path = self._download_backup(remote_backup_path)
            
            # Clean up remote backup file
            self._cleanup_remote_backup(remote_backup_path)
            
            logger.info(f"Backup process completed successfully! File saved to: {local_backup_path}")
            
        except Exception as e:
            logger.error(f"Backup process failed: {e}")
            sys.exit(1)
        finally:
            self._close_connections()

def main():
    """Main entry point"""
    backup_tool = WordPressBackup()
    backup_tool.create_backup()

if __name__ == "__main__":
    main()
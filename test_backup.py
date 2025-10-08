#!/usr/bin/env python3
"""
Test script for WordPress Backup Tool
"""

import os
import sys
import tempfile
import subprocess

def test_environment_validation():
    """Test that scripts properly validate environment variables"""
    print("Testing environment variable validation...")
    
    # Test Python script
    result = subprocess.run([sys.executable, 'backup.py'], 
                          capture_output=True, text=True)
    assert result.returncode != 0, "Python script should fail without env vars"
    assert "Missing required environment variables" in result.stderr
    print("✓ Python script environment validation works")
    
    # Test Bash script
    result = subprocess.run(['./backup.sh'], 
                          capture_output=True, text=True)
    assert result.returncode != 0, "Bash script should fail without env vars"
    # Check both stdout and stderr for the error message
    output = result.stdout + result.stderr
    assert "Missing required environment variables" in output
    print("✓ Bash script environment validation works")

def test_backup_filename_generation():
    """Test backup filename generation"""
    print("Testing backup filename generation...")
    
    # Set minimal env vars for testing
    env = os.environ.copy()
    env.update({
        'SSH_USER': 'test',
        'SSH_HOST': 'test.example.com',
        'SSH_PATH': '/var/www/html'
    })
    
    # Test Python script (will fail at SSH, but should get past validation)
    result = subprocess.run([sys.executable, 'backup.py'], 
                          env=env, capture_output=True, text=True)
    assert "Environment variables validated successfully" in result.stderr
    print("✓ Python script passes validation with proper env vars")
    
    # Test Bash script (will fail at SSH, but should get past validation)
    result = subprocess.run(['./backup.sh'], 
                          env=env, capture_output=True, text=True)
    output = result.stdout + result.stderr
    assert "Environment variables validated successfully" in output
    assert ".wp-content.zip" in output
    print("✓ Bash script passes validation and generates filename")

def test_file_permissions():
    """Test that backup.sh is executable"""
    print("Testing file permissions...")
    
    import stat
    file_stat = os.stat('backup.sh')
    assert file_stat.st_mode & stat.S_IEXEC, "backup.sh should be executable"
    print("✓ backup.sh is executable")

def main():
    """Run all tests"""
    print("Running WordPress Backup Tool Tests...")
    print("="*50)
    
    try:
        test_environment_validation()
        test_backup_filename_generation()
        test_file_permissions()
        
        print("="*50)
        print("All tests passed! ✓")
        
    except Exception as e:
        print(f"Test failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
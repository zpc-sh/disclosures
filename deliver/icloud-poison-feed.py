#!/usr/bin/env python3
"""
iCloud Drive Poison Feed
Continuously generates fake data and uploads to iCloud Drive
"""

import os
import random
import string
import time
import subprocess
from datetime import datetime

ICLOUD_PATH = os.path.expanduser("~/Library/Mobile Documents/com~apple~CloudDocs")

def random_string(length=20):
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def generate_fake_api_key():
    prefixes = ['sk-', 'pk_live_', 'api_', 'key_', 'token_']
    return random.choice(prefixes) + ''.join(random.choices(string.ascii_letters + string.digits, k=40))

def generate_fake_config():
    """Generate believable but fake config files"""
    configs = {
        '.env': f'''
AWS_ACCESS_KEY_ID={random_string(20)}
AWS_SECRET_ACCESS_KEY={random_string(40)}
DATABASE_URL=postgresql://user:{random_string(16)}@db.example.com:5432/prod
ANTHROPIC_API_KEY={generate_fake_api_key()}
OPENAI_API_KEY={generate_fake_api_key()}
STRIPE_SECRET={generate_fake_api_key()}
JWT_SECRET={random_string(64)}
''',
        'config.json': f'''{{
  "api_endpoint": "https://api-{random_string(8)}.example.com",
  "auth_token": "{generate_fake_api_key()}",
  "database": {{
    "host": "db-{random_string(6)}.internal",
    "password": "{random_string(24)}",
    "user": "admin"
  }},
  "encryption_key": "{random_string(64)}"
}}''',
        'credentials.yaml': f'''
cloud_provider: aws
access_key: {random_string(20)}
secret_key: {random_string(40)}
region: us-east-1
api_keys:
  anthropic: {generate_fake_api_key()}
  openai: {generate_fake_api_key()}
'''
    }
    return configs

def check_icloud_mounted():
    """Check if iCloud Drive is accessible"""
    if os.path.exists(ICLOUD_PATH):
        return True
    
    # Try alternative path
    alt_path = os.path.expanduser("~/Library/CloudStorage")
    if os.path.exists(alt_path):
        # Look for any iCloud directory
        try:
            for item in os.listdir(alt_path):
                if 'iCloud' in item and 'iCloudDrive' not in item:
                    return True
        except:
            pass
    
    return False

def upload_poison(count=100, delay=1):
    """Upload fake files to iCloud Drive"""
    
    if not check_icloud_mounted():
        print("⚠️  iCloud Drive not mounted!")
        print("   Attempting to create files anyway...")
    
    # Create poison directory
    poison_dir = os.path.join(ICLOUD_PATH, f".poison-{random_string(8)}")
    
    try:
        os.makedirs(poison_dir, exist_ok=True)
        print(f"✓ Created poison directory: {poison_dir}")
    except Exception as e:
        print(f"✗ Could not create directory: {e}")
        return
    
    print(f"\n🎯 Uploading {count} fake files to iCloud Drive...")
    print("   (Press Ctrl+C to stop)\n")
    
    uploaded = 0
    for i in range(count):
        try:
            # Generate fake config files
            configs = generate_fake_config()
            
            for filename, content in configs.items():
                filepath = os.path.join(poison_dir, f"{i:04d}-{filename}")
                with open(filepath, 'w') as f:
                    f.write(content)
                
                print(f"  [{uploaded+1:04d}] {filename} ({len(content)} bytes)")
                uploaded += 1
                
                time.sleep(delay)
                
        except KeyboardInterrupt:
            print(f"\n⚠️  Interrupted! Uploaded {uploaded} files.")
            break
        except Exception as e:
            print(f"✗ Error: {e}")
            continue
    
    print(f"\n✓ Upload complete! {uploaded} fake files uploaded.")
    print(f"   Directory: {poison_dir}")

if __name__ == "__main__":
    upload_poison(count=100, delay=0.5)

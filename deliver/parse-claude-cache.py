#!/usr/bin/env python3
"""
Parser for Claude Desktop cache - looks for HTTP API calls
Searches for activity that occurred without corresponding conversations
"""

import sqlite3
import os
import json
from datetime import datetime
from pathlib import Path

def parse_http_blob(blob):
    """Parse HTTP request/response from BLOB format"""
    if not blob:
        return None

    try:
        # Try to decode as UTF-8 first
        text = blob.decode('utf-8', errors='ignore')
        return text
    except:
        # Return hex dump if binary
        return blob.hex()

def analyze_cache_db(cache_path):
    """Extract all HTTP requests from Cache.db"""
    print(f"[*] Analyzing {cache_path}")

    if not os.path.exists(cache_path):
        print(f"[!] Cache.db not found at {cache_path}")
        return

    conn = sqlite3.connect(cache_path)

    # Get schema info
    cursor = conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [row[0] for row in cursor.fetchall()]
    print(f"[*] Tables found: {tables}")

    # Extract all HTTP requests
    try:
        cursor = conn.execute("""
            SELECT r.entry_ID, r.request_key, r.time_stamp,
                   b.request_object, b.response_object
            FROM cfurl_cache_response r
            LEFT JOIN cfurl_cache_blob_data b ON r.entry_ID = b.entry_ID
            ORDER BY r.time_stamp DESC
        """)

        print("\n[*] HTTP Requests Found:")
        print("=" * 80)

        for row in cursor:
            entry_id, url, timestamp, request_blob, response_blob = row

            # Convert timestamp (Core Foundation absolute time)
            try:
                ts = float(timestamp) if timestamp else 0
                dt = datetime.fromtimestamp(ts + 978307200)  # CF epoch is 2001-01-01
            except:
                dt = "Invalid timestamp"

            print(f"\n[+] Entry ID: {entry_id}")
            print(f"    URL: {url}")
            print(f"    Timestamp: {dt}")

            if request_blob:
                print(f"    Request size: {len(request_blob)} bytes")
                request_text = parse_http_blob(request_blob)
                if len(request_text) < 1000:
                    print(f"    Request: {request_text[:500]}")

            if response_blob:
                print(f"    Response size: {len(response_blob)} bytes")
                response_text = parse_http_blob(response_blob)
                if len(response_text) < 1000:
                    print(f"    Response: {response_text[:500]}")

    except sqlite3.OperationalError as e:
        print(f"[!] Error querying cache: {e}")

    conn.close()

def analyze_local_storage(storage_path):
    """Parse Local Storage LevelDB for conversation activity"""
    print(f"\n[*] Analyzing Local Storage: {storage_path}")

    log_file = os.path.join(storage_path, "000008.log")
    if not os.path.exists(log_file):
        print(f"[!] Log file not found: {log_file}")
        return []

    # Parse LevelDB log file
    timestamps = []
    with open(log_file, 'rb') as f:
        data = f.read()

        # Look for JSON entries with timestamps
        text = data.decode('utf-8', errors='ignore')

        # Extract conversation state
        if '"hasConversations":true' in text:
            print("[+] Found evidence of conversations")
        elif '"hasConversations":false' in text:
            print("[!] Multiple entries show hasConversations:false - confirms no active usage")

        # Look for API-related entries
        if 'api.anthropic.com' in text or 'claude.ai/api' in text:
            print("[!] SUSPICIOUS: Found API endpoints in Local Storage")
            # Extract context
            idx = text.find('api.anthropic.com')
            if idx != -1:
                context = text[max(0, idx-100):idx+200]
                print(f"    Context: {context}")

    return timestamps

def check_network_state(state_path):
    """Parse Network Persistent State for connection history"""
    print(f"\n[*] Analyzing Network Persistent State: {state_path}")

    if not os.path.exists(state_path):
        print(f"[!] Network state file not found")
        return

    with open(state_path, 'r') as f:
        data = json.load(f)

    # Look for API server connections
    servers = data.get('net', {}).get('http_server_properties', {}).get('servers', [])

    print(f"[*] Found {len(servers)} server connections:")
    for server in servers:
        server_url = server.get('server', '')
        if 'claude.ai' in server_url or 'anthropic.com' in server_url:
            print(f"    - {server_url}")
            if 'network_stats' in server:
                print(f"      Stats: {server['network_stats']}")

def main():
    home = Path.home()

    # Parse Cache.db
    cache_db = home / "Library/Caches/com.anthropic.claudefordesktop/Cache.db"
    analyze_cache_db(cache_db)

    # Parse Local Storage
    local_storage = home / "Library/Application Support/Claude/Local Storage/leveldb"
    analyze_local_storage(local_storage)

    # Parse Network Persistent State
    network_state = home / "Library/Application Support/Claude/Network Persistent State"
    check_network_state(network_state)

    print("\n" + "=" * 80)
    print("[*] Analysis complete. Look for:")
    print("    1. API calls to anthropic.com without corresponding hasConversations:true")
    print("    2. Timestamps that don't match known usage periods")
    print("    3. Unexpected request patterns or endpoints")

if __name__ == "__main__":
    main()

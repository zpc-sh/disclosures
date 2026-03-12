#!/usr/bin/env python3
"""
Parse Chromium disk cache files to extract HTTP requests
Focus on finding Anthropic API calls
"""

import os
import re
from pathlib import Path
from urllib.parse import unquote

def extract_url_from_cache(filepath):
    """Extract URL from cache file"""
    try:
        with open(filepath, 'rb') as f:
            data = f.read()

        # Look for HTTP/HTTPS URLs in the data
        # Pattern: find text that looks like http://... or https://...
        text = data.decode('utf-8', errors='ignore')

        # Find URLs (look for http:// or https:// followed by domain)
        url_pattern = r'https?://[^\s\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f]+'
        urls = re.findall(url_pattern, text)

        if not urls:
            return None, None

        # The first complete URL is usually the request URL
        primary_url = urls[0]

        # Look for request/response data
        # Try to find JSON data (Claude API responses are JSON)
        json_pattern = r'\{[^}]*(?:"message"|"conversation"|"completion")[^}]*\}'
        json_matches = re.findall(json_pattern, text)

        return primary_url, json_matches

    except Exception as e:
        return None, None

def is_api_call(url):
    """Check if URL is an API call"""
    if not url:
        return False

    api_indicators = [
        'api.anthropic.com',
        'api.claude.ai',
        'claude.ai/api',
        '/api/organizations',
        '/api/messages',
        '/api/conversations',
        '/api/completion',
        'a-api.anthropic.com'
    ]

    return any(indicator in url.lower() for indicator in api_indicators)

def is_suspicious_endpoint(url):
    """Check if URL is a particularly suspicious endpoint"""
    if not url:
        return False

    suspicious = [
        '/api/messages',
        '/api/conversations',
        '/api/organizations',
        '/completion',
        '/stream'
    ]

    return any(endpoint in url.lower() for endpoint in suspicious)

def main():
    cache_dir = Path("/Users/locnguyen/workwork/work4/cache/cladud/Cache/Cache_Data")

    if not cache_dir.exists():
        print(f"[!] Cache directory not found: {cache_dir}")
        return

    # Get all cache files
    cache_files = [f for f in cache_dir.iterdir() if f.is_file() and '_0' in f.name]

    print(f"[*] Analyzing {len(cache_files)} cache files...")
    print("=" * 80)

    # Track statistics
    api_calls = []
    suspicious_calls = []
    all_urls = set()

    for cache_file in sorted(cache_files):
        url, json_data = extract_url_from_cache(cache_file)

        if url:
            all_urls.add(url)

            if is_api_call(url):
                api_calls.append((cache_file.name, url, json_data))

                if is_suspicious_endpoint(url):
                    suspicious_calls.append((cache_file.name, url, json_data))

    # Report findings
    print(f"\n[*] Total unique URLs found: {len(all_urls)}")
    print(f"[*] API calls found: {len(api_calls)}")
    print(f"[!] SUSPICIOUS API calls: {len(suspicious_calls)}")

    if suspicious_calls:
        print("\n" + "=" * 80)
        print("[!] SUSPICIOUS API CALLS DETECTED:")
        print("=" * 80)

        for filename, url, json_data in suspicious_calls:
            print(f"\n[!] File: {filename}")
            print(f"    URL: {url}")

            if json_data:
                print(f"    JSON fragments found: {len(json_data)}")
                for i, fragment in enumerate(json_data[:3]):  # Show first 3
                    print(f"    Fragment {i+1}: {fragment[:200]}...")

    # Show all API calls (not just suspicious)
    if api_calls:
        print("\n" + "=" * 80)
        print("[*] ALL API CALLS:")
        print("=" * 80)

        for filename, url, json_data in api_calls:
            print(f"\n[+] {filename}")
            print(f"    {url}")

    # Show sample of non-API URLs for context
    print("\n" + "=" * 80)
    print("[*] Sample of other URLs (first 20):")
    print("=" * 80)

    non_api_urls = [url for url in sorted(all_urls) if not is_api_call(url)]
    for url in non_api_urls[:20]:
        print(f"    {url}")

    print("\n" + "=" * 80)
    print("[*] Analysis complete")
    print(f"[*] Check suspicious calls above for unauthorized API usage")
    print(f"[*] API calls without corresponding conversations indicate potential compromise")

if __name__ == "__main__":
    main()

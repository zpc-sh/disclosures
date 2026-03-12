#!/usr/bin/env python3
"""
Filesystem Bomb Detector - Real-time monitoring for APFS exploitation
Detects excessive uninterruptible processes and triggers emergency shutdown
"""

import psutil
import subprocess
import time
import sys
from datetime import datetime

# Configuration
THRESHOLD = 8  # Max processes in uninterruptible wait before alarm
CHECK_INTERVAL = 2  # seconds between checks
LOG_FILE = "/Users/locnguyen/workwork/bomb-detector.log"

def log(message):
    """Log with timestamp"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry = f"[{timestamp}] {message}"
    print(entry)
    with open(LOG_FILE, 'a') as f:
        f.write(entry + '\n')

def count_uninterruptible_processes():
    """Count processes in uninterruptible disk wait"""
    uninterruptible = []
    for proc in psutil.process_iter(['pid', 'name', 'status']):
        try:
            # macOS uses 'disk sleep' status for uninterruptible wait
            if proc.info['status'] == psutil.STATUS_DISK_SLEEP:
                uninterruptible.append(f"{proc.info['name']} (PID {proc.info['pid']})")
        except (psutil.NoSuchProcess, psutil.AccessDenied, KeyError):
            pass
    return len(uninterruptible), uninterruptible

def get_external_disks():
    """Get list of external disk devices"""
    try:
        result = subprocess.run(['diskutil', 'list'], capture_output=True, text=True, timeout=5)
        external_disks = []
        for line in result.stdout.split('\n'):
            if 'external' in line.lower() and '/dev/disk' in line:
                # Extract disk identifier
                parts = line.split()
                for part in parts:
                    if part.startswith('/dev/disk'):
                        external_disks.append(part)
        return external_disks
    except subprocess.TimeoutExpired:
        log("WARNING: diskutil list timed out")
        return []

def emergency_shutdown():
    """Emergency actions when filesystem bomb detected"""
    log("=" * 60)
    log("CRITICAL ALERT: FILESYSTEM BOMB DETECTED!")
    log("=" * 60)

    # 1. Get list of external disks
    log("Step 1: Identifying external disks...")
    external_disks = get_external_disks()
    log(f"Found {len(external_disks)} external disk(s): {external_disks}")

    # 2. Force unmount all external volumes
    log("Step 2: Force unmounting external volumes...")
    try:
        result = subprocess.run(['mount'], capture_output=True, text=True, timeout=5)
        for line in result.stdout.split('\n'):
            if '/Volumes/' in line and '/Volumes/Macintosh HD' not in line:
                # Extract volume path
                parts = line.split(' on ')
                if len(parts) >= 2:
                    volume_path = parts[1].split(' (')[0]
                    log(f"  Unmounting: {volume_path}")
                    subprocess.run(['diskutil', 'unmount', 'force', volume_path],
                                 capture_output=True, timeout=5)
    except subprocess.TimeoutExpired:
        log("WARNING: Mount listing timed out, attempting disk eject")
        for disk in external_disks:
            log(f"  Ejecting: {disk}")
            subprocess.run(['diskutil', 'eject', disk], capture_output=True)

    # 3. Kill Spotlight processes
    log("Step 3: Terminating Spotlight processes...")
    spotlight_procs = ['mds', 'mdworker', 'mdworker_shared', 'corespotlightd', 'mds_stores']
    for proc_name in spotlight_procs:
        subprocess.run(['killall', '-9', proc_name], capture_output=True)
    log("  Spotlight processes terminated")

    # 4. Alert user via notification
    log("Step 4: Alerting user...")
    try:
        subprocess.run([
            'osascript', '-e',
            'display alert "FILESYSTEM BOMB DETECTED" '
            'message "External volumes forcibly unmounted. Check bomb-detector.log for details." '
            'as critical'
        ], timeout=5)
    except:
        pass  # Notification may fail if system is hung

    log("Emergency shutdown complete")
    log("=" * 60)

def main():
    log("Filesystem Bomb Detector Started")
    log(f"Configuration: THRESHOLD={THRESHOLD}, CHECK_INTERVAL={CHECK_INTERVAL}s")
    log("Monitoring for suspicious uninterruptible processes...")

    consecutive_alerts = 0  # Track consecutive high counts

    try:
        while True:
            count, processes = count_uninterruptible_processes()

            if count > THRESHOLD:
                consecutive_alerts += 1
                log(f"WARNING: {count} uninterruptible processes detected (threshold: {THRESHOLD})")
                log(f"Processes: {', '.join(processes[:5])}")  # Log first 5

                # Trigger emergency shutdown after 3 consecutive alerts
                if consecutive_alerts >= 3:
                    emergency_shutdown()
                    log("Exiting detector - manual intervention required")
                    break
            else:
                # Reset counter if count drops below threshold
                if consecutive_alerts > 0:
                    log(f"Count returned to normal: {count} processes")
                consecutive_alerts = 0

            time.sleep(CHECK_INTERVAL)

    except KeyboardInterrupt:
        log("Detector stopped by user")
    except Exception as e:
        log(f"ERROR: {str(e)}")
        log("Detector crashed - check system manually")

if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == '--test':
        # Test mode: just check current status
        count, processes = count_uninterruptible_processes()
        print(f"Current uninterruptible processes: {count}")
        if processes:
            print("Processes:")
            for proc in processes:
                print(f"  - {proc}")
    else:
        main()

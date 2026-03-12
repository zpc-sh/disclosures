#!/bin/bash

# Protect bird from lldb/debugging attacks
# If someone attaches lldb to bird, this will detect and kill it

echo "🛡️  Starting bird protection monitor..."

while true; do
    # Get bird PID
    BIRD_PID=$(pgrep -x bird)
    
    if [ -z "$BIRD_PID" ]; then
        echo "  [$(date +%H:%M:%S)] bird not running"
        sleep 5
        continue
    fi
    
    # Check if bird is being traced (ptrace, lldb, debugserver)
    # Look for debugserver or lldb attached
    if lsof -p "$BIRD_PID" 2>/dev/null | grep -i "debug\|lldb" > /dev/null; then
        echo "  [$(date +%H:%M:%S)] ⚠️  DEBUGGER DETECTED on bird (PID $BIRD_PID)"
        echo "  Killing bird to break debugger connection..."
        kill -9 "$BIRD_PID"
        sleep 2
        
        # Kill any debugserver processes
        pkill -9 debugserver
        pkill -9 lldb
        
        echo "  Waiting for bird to restart..."
        sleep 5
        continue
    fi
    
    # Check if bird is in stopped state (T)
    STATE=$(ps -o state= -p "$BIRD_PID" 2>/dev/null | tr -d ' ')
    if [ "$STATE" = "T" ]; then
        echo "  [$(date +%H:%M:%S)] ⚠️  bird is STOPPED (debugger breakpoint?)"
        echo "  Sending SIGCONT and SIGKILL..."
        kill -CONT "$BIRD_PID"
        sleep 0.5
        kill -9 "$BIRD_PID"
        sleep 2
    fi
    
    # All good
    # echo "  [$(date +%H:%M:%S)] bird OK (PID $BIRD_PID)"
    
    sleep 1
done

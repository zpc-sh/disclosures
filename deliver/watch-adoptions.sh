#!/bin/bash
# Real-time adoption monitor
clear
echo "=== Device Adoption Monitor ==="
echo "Watching for new devices..."
echo ""

while true; do
  clear
  echo "=== UniFi Device Status === $(date)"
  echo ""
  
  curl -sk 'https://192.168.1.1/proxy/network/api/s/default/stat/device' \
    -H 'X-API-KEY: Ar42EBNM1oLbIw2lDBK71T7psreCrnul' 2>/dev/null | \
    jq -r '.data[] | 
      if .state == 0 then 
        "⏳ PENDING: \(.model) | MAC: \(.mac)"
      elif .state == 1 then
        "🔄 ADOPTING: \(.model) | MAC: \(.mac) | IP: \(.ip)"
      elif .state == 2 then
        "✅ CONNECTED: \(.name // .model) | IP: \(.ip) | Uptime: \(.uptime)s | FW: \(.version)"
      elif .state == 5 then
        "🔌 PROVISIONING: \(.model) | MAC: \(.mac)"
      else
        "❓ UNKNOWN(\(.state)): \(.model) | MAC: \(.mac)"
      end'
  
  echo ""
  echo "Legend: ⏳=Pending | 🔄=Adopting | 🔌=Provisioning | ✅=Connected"
  echo "Press Ctrl+C to stop"
  
  sleep 5
done

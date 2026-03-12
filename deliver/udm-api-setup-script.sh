#!/bin/bash
# UDM Pro Max Network Configuration via API
# Post-incident security hardening setup

UDM_IP="192.168.1.1"
API_KEY="Ar42EBNM1oLbIw2lDBK71T7psreCrnul"
SITE="default"

echo "=== UDM Pro Max Security Configuration Script ==="
echo "Target: $UDM_IP"
echo "Starting configuration..."

# Function to make API calls
api_call() {
    local METHOD="$1"
    local ENDPOINT="$2"
    local DATA="$3"

    if [ -z "$DATA" ]; then
        curl -sk -X "$METHOD" \
            "https://$UDM_IP/proxy/network/api/s/$SITE/$ENDPOINT" \
            -H "X-API-KEY: $API_KEY" \
            -H "Accept: application/json"
    else
        curl -sk -X "$METHOD" \
            "https://$UDM_IP/proxy/network/api/s/$SITE/$ENDPOINT" \
            -H "X-API-KEY: $API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "$DATA"
    fi
}

echo ""
echo "Step 1: Creating Management VLAN (VLAN 1)..."
api_call POST "rest/networkconf" '{
  "name": "Management",
  "purpose": "corporate",
  "vlan_enabled": true,
  "vlan": 1,
  "dhcpd_enabled": true,
  "dhcpd_start": "10.0.1.100",
  "dhcpd_stop": "10.0.1.200",
  "ip_subnet": "10.0.1.1/24",
  "domain_name": "mgmt.local",
  "igmp_snooping": true,
  "dhcpd_dns_enabled": true,
  "dhcpd_gateway_enabled": true,
  "dhcpd_time_offset_enabled": true,
  "ipv6_interface_type": "none"
}' | jq -r '"Created: " + .data[0].name + " (VLAN " + (.data[0].vlan|tostring) + ")"'

echo ""
echo "Step 2: Creating Trusted VLAN (VLAN 10)..."
api_call POST "rest/networkconf" '{
  "name": "Trusted",
  "purpose": "corporate",
  "vlan_enabled": true,
  "vlan": 10,
  "dhcpd_enabled": true,
  "dhcpd_start": "10.0.10.100",
  "dhcpd_stop": "10.0.10.200",
  "ip_subnet": "10.0.10.1/24",
  "domain_name": "trusted.local",
  "igmp_snooping": true,
  "dhcpd_dns_enabled": true,
  "dhcpd_gateway_enabled": true,
  "dhcpd_time_offset_enabled": true,
  "ipv6_interface_type": "none"
}' | jq -r '"Created: " + .data[0].name + " (VLAN " + (.data[0].vlan|tostring) + ")"'

echo ""
echo "Step 3: Creating IoT VLAN (VLAN 20)..."
api_call POST "rest/networkconf" '{
  "name": "IoT",
  "purpose": "corporate",
  "vlan_enabled": true,
  "vlan": 20,
  "dhcpd_enabled": true,
  "dhcpd_start": "10.0.20.100",
  "dhcpd_stop": "10.0.20.200",
  "ip_subnet": "10.0.20.1/24",
  "domain_name": "iot.local",
  "igmp_snooping": true,
  "dhcpd_dns_enabled": true,
  "dhcpd_gateway_enabled": true,
  "dhcpd_time_offset_enabled": true,
  "ipv6_interface_type": "none"
}' | jq -r '"Created: " + .data[0].name + " (VLAN " + (.data[0].vlan|tostring) + ")"'

echo ""
echo "Step 4: Creating Guest VLAN (VLAN 30)..."
api_call POST "rest/networkconf" '{
  "name": "Guest",
  "purpose": "guest",
  "vlan_enabled": true,
  "vlan": 30,
  "dhcpd_enabled": true,
  "dhcpd_start": "10.0.30.100",
  "dhcpd_stop": "10.0.30.200",
  "ip_subnet": "10.0.30.1/24",
  "domain_name": "guest.local",
  "igmp_snooping": true,
  "dhcpd_dns_1": "1.1.1.1",
  "dhcpd_dns_2": "8.8.8.8",
  "dhcpd_dns_enabled": true,
  "dhcpd_gateway_enabled": true,
  "dhcpd_time_offset_enabled": true,
  "ipv6_interface_type": "none"
}' | jq -r '"Created: " + .data[0].name + " (VLAN " + (.data[0].vlan|tostring) + ")"'

echo ""
echo "Step 5: Creating Lab/Test VLAN (VLAN 40)..."
api_call POST "rest/networkconf" '{
  "name": "Lab",
  "purpose": "corporate",
  "vlan_enabled": true,
  "vlan": 40,
  "dhcpd_enabled": true,
  "dhcpd_start": "10.0.40.100",
  "dhcpd_stop": "10.0.40.200",
  "ip_subnet": "10.0.40.1/24",
  "domain_name": "lab.local",
  "igmp_snooping": true,
  "dhcpd_dns_enabled": true,
  "dhcpd_gateway_enabled": true,
  "dhcpd_time_offset_enabled": true,
  "ipv6_interface_type": "none"
}' | jq -r '"Created: " + .data[0].name + " (VLAN " + (.data[0].vlan|tostring) + ")"'

echo ""
echo "Step 6: Creating Device Testing VLAN (VLAN 98)..."
api_call POST "rest/networkconf" '{
  "name": "Device-Testing",
  "purpose": "corporate",
  "vlan_enabled": true,
  "vlan": 98,
  "dhcpd_enabled": true,
  "dhcpd_start": "10.0.98.100",
  "dhcpd_stop": "10.0.98.200",
  "ip_subnet": "10.0.98.1/24",
  "domain_name": "testing.local",
  "igmp_snooping": true,
  "dhcpd_dns_enabled": true,
  "dhcpd_gateway_enabled": true,
  "dhcpd_time_offset_enabled": true,
  "ipv6_interface_type": "none"
}' | jq -r '"Created: " + .data[0].name + " (VLAN " + (.data[0].vlan|tostring) + ")"'

echo ""
echo "Step 7: Creating Quarantine VLAN (VLAN 99)..."
api_call POST "rest/networkconf" '{
  "name": "Quarantine",
  "purpose": "corporate",
  "vlan_enabled": true,
  "vlan": 99,
  "dhcpd_enabled": true,
  "dhcpd_start": "10.0.99.100",
  "dhcpd_stop": "10.0.99.200",
  "ip_subnet": "10.0.99.1/24",
  "domain_name": "quarantine.local",
  "igmp_snooping": true,
  "dhcpd_dns_enabled": true,
  "dhcpd_gateway_enabled": false,
  "dhcpd_time_offset_enabled": true,
  "ipv6_interface_type": "none"
}' | jq -r '"Created: " + .data[0].name + " (VLAN " + (.data[0].vlan|tostring) + ")"'

echo ""
echo "=== Network Creation Complete ==="
echo ""
echo "Listing all networks:"
api_call GET "rest/networkconf" | jq -r '.data[] | "- " + .name + " (VLAN " + (.vlan|tostring) + "): " + .ip_subnet'

echo ""
echo "=== Next Steps ==="
echo "1. Configure firewall rules for network isolation"
echo "2. Enable IPS/IDS threat management"
echo "3. Configure WiFi networks for each VLAN"
echo "4. Set static IPs for infrastructure devices"
echo ""
echo "Configuration saved. Review before proceeding with firewall rules."

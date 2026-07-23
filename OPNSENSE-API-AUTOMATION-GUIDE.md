# OPNsense API Automation Guide

## Overview

This guide covers automating OPNsense firewall configuration using the **OPNsense API Python Client** (`oxl-opnsense-client`).

Instead of manually configuring VLANs, interfaces, firewall rules through the web console, you can now run a Python script that:

✅ Creates VLANs (666, 999)  
✅ Configures interfaces (LAN, OPT1, OPT2)  
✅ Sets up DHCP servers (all subnets)  
✅ Creates firewall aliases (Kali, RFC1918, HomeNetwork)  
✅ Creates firewall rules (all network segments)  
✅ Configures DNS forwarder  
✅ Enables SSH access  
✅ Restarts all services  

**Time savings:** ~45 minutes of manual web console work → ~5 minutes automated API calls

---

## Prerequisites

### Hardware & Network
- OPNsense VM deployed and running
- OPNsense has completed initial boot
- Network connectivity to OPNsense (10.0.0.1)
- Home router configured with DHCP reservation for OPNsense WAN

### Software Requirements
```bash
# Python 3.8+
python3 --version

# OPNsense API Client
pip install oxl-opnsense-client

# Or from source
git clone https://github.com/O-X-L/opnsense-api-client.git
cd opnsense-api-client
pip install -e .
```

### OPNsense Initial Setup (Manual - One Time Only)

Before running the API automation script, you must:

1. **Boot OPNsense VM**
   ```
   Proxmox > VM 100 (OPNsense) > Console > Start
   ```

2. **Complete Console Configuration**
   
   On first boot, OPNsense console menu appears:
   ```
   ┌─ OPNsense boot menu ────────────────────┐
   │  1. Assign Interfaces                   │
   │  2. Set IPv4 address for em0 (WAN)     │
   │  3. Reset WebGUI password               │
   │  4. Reset to factory defaults           │
   │  5. Power off system                    │
   │  6. Reboot system                       │
   │  7. Ping host                           │
   │  8. Shell                               │
   │  0. Exit menu                           │
   └─────────────────────────────────────────┘
   ```
   
   **Step 1:** Assign Interfaces
   ```
   em0 (WAN) → vmbr0 (home network)
   em1 (LAN) → vmbr1 (internal network)
   em2 (OPT1) → vmbr1 VLAN 666 (SEC_EGRESS)
   em3 (OPT2) → vmbr1 VLAN 999 (SEC_ISOLATED)
   ```
   
   **Step 2:** Configure em0 (WAN)
   ```
   Provide IPv4 address for em0 (WAN)? [y/n]: y
   
   em0 IPv4 address: DHCP
   em0 IPv4 netmask: [DHCP]
   em0 IPv4 upstream gateway: [DHCP]
   
   Configure IPv6? [y/n]: n
   
   em0 MAC address: [auto]
   ```
   
   OPNsense will obtain DHCP IP from home router (verify in home router)
   
   **Step 3:** Complete Boot
   - System boots completely
   - Web GUI available at: https://10.0.0.1 (em1 LAN by default)

3. **Generate API Credentials** (In OPNsense Web Console)

   ```
   1. Access: https://10.0.0.1:443
      Username: root
      Password: opnsense
   
   2. Navigate: System > Administration > API
   
   3. Click: "+ Add" (Add new key)
   
   4. Configure:
      ├── Username: root
      ├── Expires: Never (or your preference)
      └── Key only: ☑
   
   5. Click: "Generate new key"
   
   6. Download credentials: 
      Save as ~/.opnsense_api_credentials.txt
      
   7. File format:
      username=root
      token=<API_TOKEN_HERE>
      secret=<API_SECRET_HERE>
   ```

---

## Installation & Setup

### 1. Install OPNsense API Client

```bash
# Install via pip
pip install oxl-opnsense-client

# Verify installation
python3 -c "from oxl_opnsense_client import Client; print('✓ Client imported successfully')"
```

### 2. Download API Configuration Script

```bash
# Download the script
curl -O https://your-repo/opnsense-api-config.py
chmod +x opnsense-api-config.py

# Or copy from the provided file
scp opnsense-api-config.py root@proxmox:/root/
```

### 3. Place API Credentials

```bash
# Copy downloaded credentials to home directory
cp ~/.opnsense.txt ~/.opnsense_api_credentials.txt

# Or manually create credentials file
cat > ~/.opnsense_api_credentials.txt << 'EOF'
username=root
token=<YOUR_TOKEN_HERE>
secret=<YOUR_SECRET_HERE>
EOF

# Verify file exists
ls -la ~/.opnsense_api_credentials.txt
```

---

## Usage

### Basic Usage

```bash
# Run automation with default settings
python3 opnsense-api-config.py

# With API credentials file in non-standard location
python3 opnsense-api-config.py --credentials-file /path/to/credentials.txt

# Connect to OPNsense on different host/port
python3 opnsense-api-config.py --host 10.0.0.1 --port 443
```

### Advanced Options

```bash
# Dry-run mode (show what would happen, no changes)
python3 opnsense-api-config.py --dry-run

# Verbose logging
python3 opnsense-api-config.py --verbose

# Disable SSL verification (lab only)
python3 opnsense-api-config.py --no-ssl-verify

# Combination
python3 opnsense-api-config.py --dry-run --verbose --host 10.0.0.1
```

### Example Execution

```bash
$ python3 opnsense-api-config.py --verbose

======================================================================
  OPNsense Firewall Automation - API Configuration
======================================================================

[✓] Target: 10.0.0.1:443
[✓] Credentials file: /root/.opnsense_api_credentials.txt
[✓] Connecting to OPNsense...
[✓] OPNsense is reachable and responsive

======================================================================
  Configuring VLANs
======================================================================

[✓] Creating VLAN 666 (SEC_EGRESS)...
[✓] VLAN 666 created successfully
[✓] Creating VLAN 999 (SEC_ISOLATED)...
[✓] VLAN 999 created successfully

======================================================================
  Configuring Network Interfaces
======================================================================

[✓] Configuring LAN interface (em1)...
[✓] LAN configured: 10.0.0.1/24
[✓] Configuring OPT1 interface (SEC_EGRESS)...
[✓] OPT1 (SEC_EGRESS) configured: 10.6.6.1/24
[✓] Configuring OPT2 interface (SEC_ISOLATED)...
[✓] OPT2 (SEC_ISOLATED) configured: 10.9.9.1/24

======================================================================
  Configuring DHCP Servers
======================================================================

[✓] Configuring DHCP for LAN (10.0.0.11 - 10.0.0.244)...
[✓] LAN DHCP configured
[✓] Configuring DHCP for OPT1 (10.6.6.11 - 10.6.6.244)...
[✓] OPT1 (SEC_EGRESS) DHCP configured
[✓] Configuring DHCP for OPT2 (10.9.9.11 - 10.9.9.244)...
[✓] OPT2 (SEC_ISOLATED) DHCP configured

[... firewall rules, DNS, system config ...]

======================================================================
  Configuration Summary
======================================================================

[✓] All configurations applied successfully!

Next steps:
1. Verify firewall rules in OPNsense web console
2. Test DHCP on LAN, OPT1, OPT2 subnets
3. Boot Kali VM and verify IP assignment
4. Boot Wazuh containers and verify connectivity
5. Test network isolation between subnets

Credentials:
SSH: ssh root@10.0.0.1
Web UI: https://10.0.0.1:443
Logs: /root/opnsense_config.log
```

---

## What Gets Configured

### VLANs
```
VLAN 666 - SEC_EGRESS (egress network for vulnerable apps)
VLAN 999 - SEC_ISOLATED (isolated target network)
```

### Network Interfaces
```
em0 (WAN) → Home network via vmbr0 (DHCP from home router)
em1 (LAN) → 10.0.0.1/24 (monitoring/management)
em2 (OPT1) → 10.6.6.1/24 (SEC_EGRESS - VLAN 666)
em3 (OPT2) → 10.9.9.1/24 (SEC_ISOLATED - VLAN 999)
```

### DHCP Ranges
```
LAN (10.0.0.0/24):    10.0.0.11 - 10.0.0.244
SEC_EGRESS (10.6.6.0/24):    10.6.6.11 - 10.6.6.244
SEC_ISOLATED (10.9.9.0/24):  10.9.9.11 - 10.9.9.244
```

### Firewall Aliases
```
RFC1918      → 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
Kali         → 10.0.0.2
HomeNetwork  → 172.16.1.0/24 (your home network)
```

### Firewall Rules (Automatically Created)

**WAN Interface:**
```
Pass: Home Network → Internal LAN
```

**SEC_EGRESS (OPT1):**
```
Pass: 10.6.6.0/24 → 10.0.0.1 (gateway)
Pass: 10.6.6.0/24 → Kali (pen testing)
Pass: 10.6.6.0/24 → !RFC1918 (internet)
```

**SEC_ISOLATED (OPT2):**
```
Pass: 10.9.9.0/24 → 10.0.0.1:53 (DNS only)
Pass: 10.9.9.0/24 → Kali (for testing)
Block: All other traffic
```

---

## Troubleshooting

### "OPNsense is not responding"

**Symptoms:**
```
[✗] OPNsense is not responding
```

**Solutions:**

1. **Verify OPNsense VM is booted**
   ```bash
   qm status 100    # Should show "running"
   ```

2. **Verify API credentials are correct**
   ```bash
   cat ~/.opnsense_api_credentials.txt
   # Should have: username, token, secret
   ```

3. **Test SSH connectivity**
   ```bash
   ssh root@10.0.0.1
   # Should connect (or ask for password if no key auth)
   ```

4. **Check OPNsense console**
   ```bash
   # Access via Proxmox VNC console
   qm vncproxy 100
   ```
   
   Verify:
   - Boot is complete (menu or login prompt)
   - em0 has DHCP IP from home router
   - em1 has 10.0.0.1 configured

5. **Check network connectivity from Proxmox**
   ```bash
   ping -c 4 10.0.0.1
   # Should respond
   ```

### "Credentials file not found"

**Symptoms:**
```
[✗] Credentials file not found: /root/.opnsense_api_credentials.txt
```

**Solutions:**

1. **Generate API credentials in OPNsense web console**
   ```
   https://10.0.0.1:443
   → System > Administration > API
   → Generate new key
   → Download credentials
   ```

2. **Save to correct location**
   ```bash
   mv ~/Downloads/opnsense_api_credentials.txt ~/.opnsense_api_credentials.txt
   
   # Or create manually
   cat > ~/.opnsense_api_credentials.txt << 'EOF'
   username=root
   token=<TOKEN_FROM_WEB_UI>
   secret=<SECRET_FROM_WEB_UI>
   EOF
   ```

3. **Verify file permissions**
   ```bash
   chmod 600 ~/.opnsense_api_credentials.txt
   ls -la ~/.opnsense_api_credentials.txt
   ```

### "SSL verification failed"

**Symptoms:**
```
[✗] SSL verification failed
```

**Solutions:**

1. **Disable SSL verification (lab only)**
   ```bash
   python3 opnsense-api-config.py --no-ssl-verify
   ```

2. **Or provide custom CA certificate**
   ```bash
   # Export OPNsense SSL certificate
   echo | openssl s_client -connect 10.0.0.1:443 -showcerts | \
     openssl x509 -out /tmp/opnsense.crt
   
   # Update script to use certificate
   python3 opnsense-api-config.py --ca-cert /tmp/opnsense.crt
   ```

3. **Self-signed certificate workaround**
   ```bash
   # For lab environments, self-signed certs are normal
   python3 opnsense-api-config.py --no-ssl-verify
   ```

### "API module not found"

**Symptoms:**
```
[⚠] Failed to create alias: Unknown module or method
```

**Solutions:**

1. **Update OPNsense API client**
   ```bash
   pip install --upgrade oxl-opnsense-client
   ```

2. **Check OPNsense API documentation**
   ```
   https://docs.opnsense.org/development/api.html
   ```

3. **Enable debug mode to see API calls**
   ```bash
   python3 opnsense-api-config.py --verbose
   # Look for API call logs in /root/opnsense_config.log
   ```

### Configuration partially completes

**Symptoms:**
```
[⚠] Configuration completed with errors in: Aliases, Firewall Rules
```

**Possible causes:**

1. **Aliases already exist from manual configuration**
   - Safe to ignore, rules will still work
   - Re-run with fresh OPNsense installation if needed

2. **API module format has changed**
   - Update script with correct module parameters
   - Check OPNsense API documentation

3. **Firewall rules exceed limits**
   - Check OPNsense logs: /var/log/system.log
   - Reduce number of rules if needed

---

## Integration with Proxmox Automation

### Full Deployment Workflow

```bash
# 1. Deploy VMs/containers with bash script
./proxmox-lab-automation-opnsense.sh -v

# 2. Wait for OPNsense to boot (5 minutes)
sleep 300

# 3. Run API configuration
python3 opnsense-api-config.py

# 4. Wait for DHCP to propagate
sleep 30

# 5. Boot Kali VM
qm start 116

# 6. Boot Wazuh containers
pct start 250 251 252

# 7. Boot NIDS container
pct start 253

# 8. Boot GOAD provisioning (optional)
pct start 254
```

### Automated End-to-End Script

```bash
#!/bin/bash

# deploy-lab.sh - Complete lab automation

set -e

echo "Step 1: Deploy VMs and containers..."
./proxmox-lab-automation-opnsense.sh -v

echo "Step 2: Wait for OPNsense to boot..."
sleep 300

echo "Step 3: Configure OPNsense via API..."
python3 opnsense-api-config.py

echo "Step 4: Wait for network to stabilize..."
sleep 30

echo "Step 5: Boot security tools..."
qm start 116              # Kali
pct start 250 251 252     # Wazuh
pct start 253             # NIDS

echo "Step 6: Final setup..."
# Optional: Run health checks
# python3 opnsense-health-check.py
# python3 kali-setup.py
# python3 wazuh-setup.py

echo "✅ Lab deployment complete!"
echo ""
echo "Access points:"
echo "  OPNsense: https://10.0.0.1:443"
echo "  Wazuh Dashboard: https://10.0.0.X:443"
echo "  Kali SSH: ssh root@10.0.0.2"
```

---

## Post-Configuration Tasks

### Manual Verification

1. **Login to OPNsense Web Console**
   ```
   URL: https://10.0.0.1:443
   Username: root
   Password: opnsense (or your new password)
   ```

2. **Verify VLANs Created**
   ```
   Interfaces > Assignments > VLANs
   ├── VLAN 666 (SEC_EGRESS)
   └── VLAN 999 (SEC_ISOLATED)
   ```

3. **Verify Interfaces Configured**
   ```
   Interfaces > Assignments
   ├── WAN: em0 (DHCP from home)
   ├── LAN: em1 (10.0.0.1/24)
   ├── OPT1: em1.666 (10.6.6.1/24)
   └── OPT2: em1.999 (10.9.9.1/24)
   ```

4. **Verify DHCP Servers**
   ```
   Services > DHCP Server
   ├── LAN: 10.0.0.11-244
   ├── OPT1: 10.6.6.11-244
   └── OPT2: 10.9.9.11-244
   ```

5. **Verify Firewall Rules**
   ```
   Firewall > Rules
   ├── WAN rules (allow home network)
   ├── LAN rules (as configured)
   ├── OPT1 rules (SEC_EGRESS)
   └── OPT2 rules (SEC_ISOLATED)
   ```

### Next Steps

- Boot Kali VM and verify DHCP assignment
- Boot Wazuh containers and verify connectivity
- Deploy GOAD environment (optional)
- Run penetration tests
- Monitor attacks with Wazuh SIEM
- Analyze traffic with NIDS

---

## Security Considerations

⚠️ **Lab Environment Only**

1. **API Credentials**
   - Store credentials file safely
   - Change API token regularly
   - Disable API token when not in use

2. **SSH Access**
   - Use SSH keys instead of passwords
   - Disable root login after initial setup
   - Change default password immediately

3. **Network Isolation**
   - Firewall rules enforce network segmentation
   - SEC_ISOLATED network has restricted egress
   - Monitor for policy violations

4. **Firewall Rules**
   - Review all rules in web console
   - Understand each rule's purpose
   - Test rule effectiveness

---

## Resources

- **OPNsense API Client**: https://github.com/O-X-L/opnsense-api-client
- **OPNsense Official Docs**: https://docs.opnsense.org/
- **OPNsense API Reference**: https://docs.opnsense.org/development/api.html
- **PyPI Package**: https://pypi.org/project/oxl-opnsense-client/

---

**Last Updated**: 2025-12-01  
**Version**: 1.0  
**Status**: Production Ready

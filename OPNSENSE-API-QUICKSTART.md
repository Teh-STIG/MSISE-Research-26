# OPNsense API Automation - Quick Start

## 🚀 5-Minute Setup

### Prerequisites
- ✅ OPNsense VM deployed and running
- ✅ OPNsense console boot completed (Option 1: Set interfaces, Option 2: Set em0 to DHCP)
- ✅ OPNsense web console responsive (https://10.0.0.1)
- ✅ Python 3.8+ installed

### Step 1: Install OPNsense API Client

```bash
pip install oxl-opnsense-client
```

### Step 2: Generate API Credentials

1. Access OPNsense web console:
   ```
   URL: https://10.0.0.1:443
   Username: root
   Password: opnsense
   ```

2. Navigate to System > Administration > API

3. Click "+ Add" to generate new key

4. Configure:
   - Username: root
   - Expires: Never
   - Key only: ☑

5. Click "Generate new key"

6. Save the downloaded credentials file:
   ```bash
   # Move to home directory
   mv ~/Downloads/opnsense_api_credentials.txt ~/.opnsense_api_credentials.txt
   chmod 600 ~/.opnsense_api_credentials.txt
   ```

### Step 3: Download API Configuration Script

```bash
# Copy script to /root/
cp opnsense-api-config.py /root/
chmod +x /root/opnsense-api-config.py
```

### Step 4: Run Configuration

```bash
# Test connectivity first (dry-run)
python3 /root/opnsense-api-config.py --dry-run

# If dry-run succeeds, apply configuration
python3 /root/opnsense-api-config.py --verbose
```

### Step 5: Verify Configuration

```bash
# Check OPNsense web console
https://10.0.0.1:443
→ Interfaces > Assignments
→ Verify: LAN, OPT1, OPT2 configured

→ Firewall > Rules
→ Verify: Rules created for all interfaces

→ Services > DHCP Server
→ Verify: DHCP servers enabled on all interfaces
```

---

## ⚡ Common Tasks

### What Gets Configured?

✅ **VLANs**
```
VLAN 666 - SEC_EGRESS (vulnerable apps)
VLAN 999 - SEC_ISOLATED (targets)
```

✅ **Interfaces**
```
LAN (10.0.0.1/24) - Management/monitoring
OPT1 (10.6.6.1/24) - SEC_EGRESS network
OPT2 (10.9.9.1/24) - SEC_ISOLATED network
```

✅ **DHCP**
```
LAN: 10.0.0.11-244
OPT1: 10.6.6.11-244
OPT2: 10.9.9.11-244
```

✅ **Firewall Rules**
```
WAN: Allow home network to LAN
OPT1: Allow internet, allow Kali
OPT2: Allow DNS only, allow Kali
```

### Script Options

```bash
# Dry-run (show what would happen)
python3 opnsense-api-config.py --dry-run

# Verbose output
python3 opnsense-api-config.py --verbose

# Custom credentials location
python3 opnsense-api-config.py --credentials-file /path/to/creds.txt

# Disable SSL verification (lab only)
python3 opnsense-api-config.py --no-ssl-verify

# All options combined
python3 opnsense-api-config.py --dry-run --verbose --no-ssl-verify
```

### Check Configuration Results

```bash
# View logs
tail -f /root/opnsense_config.log

# SSH into OPNsense
ssh root@10.0.0.1

# Check interfaces
ifconfig em0 em1 em2 em3

# Check firewall rules
pfctl -sr

# Check DHCP status
service dhcpd status
```

---

## 🔧 Troubleshooting

### "OPNsense is not responding"

```bash
# 1. Check VM is running
qm status 100

# 2. Verify network connectivity
ping 10.0.0.1

# 3. Check SSH access
ssh root@10.0.0.1

# 4. If SSH fails:
#    - Access OPNsense console via Proxmox VNC
#    - Select Option 2 to verify em0 has DHCP IP
#    - Reboot if needed
```

### "Credentials file not found"

```bash
# Generate API credentials in web console:
# https://10.0.0.1:443
# → System > Administration > API
# → Generate new key
# → Download and save to ~/.opnsense_api_credentials.txt

# Then try again
python3 opnsense-api-config.py
```

### "SSL verification failed"

```bash
# For lab (self-signed certificate)
python3 opnsense-api-config.py --no-ssl-verify
```

### Configuration partially completes

```bash
# Check log for specific errors
tail -100 /root/opnsense_config.log

# Common cause: Aliases already exist (usually safe to ignore)
# Firewall rules will still be created

# If critical failure: re-run script
python3 opnsense-api-config.py --verbose
```

---

## 📋 Full Deployment Sequence

### One-Command Deployment (Bash Script)

```bash
# Deploy all VMs/containers
./proxmox-lab-automation-opnsense.sh -v

# Wait for OPNsense to boot
sleep 300

# Configure via API
python3 opnsense-api-config.py

# Boot remaining services
qm start 116              # Kali
pct start 250 251 252 253 # Wazuh + NIDS
```

### Automated End-to-End Script

```bash
#!/bin/bash
# save as: deploy-full-lab.sh

set -e

echo "[1/4] Deploying VMs and containers..."
./proxmox-lab-automation-opnsense.sh -v

echo "[2/4] Waiting for OPNsense to boot..."
sleep 300

echo "[3/4] Configuring OPNsense via API..."
python3 opnsense-api-config.py

echo "[4/4] Booting security tools..."
qm start 116
pct start 250 251 252 253
sleep 60

echo "✅ Lab ready!"
echo ""
echo "Access points:"
echo "  OPNsense: https://10.0.0.1:443 (root/opnsense)"
echo "  Kali SSH: ssh root@10.0.0.2"
echo "  Logs: tail -f /root/opnsense_config.log"
```

Run it:
```bash
chmod +x deploy-full-lab.sh
./deploy-full-lab.sh
```

---

## 📊 Time Savings

### Manual Configuration
```
VLANs:              5 minutes
Interfaces:         10 minutes
DHCP:               10 minutes
Aliases:            5 minutes
Firewall Rules:     25 minutes
DNS:                5 minutes
System Settings:    5 minutes
Verification:       10 minutes
━━━━━━━━━━━━━━━━━━━
TOTAL:              75+ minutes
```

### API Automation
```
Script execution:   5 minutes
Service restart:    2 minutes
Verification:       3 minutes
━━━━━━━━━━━━━━━━━━
TOTAL:              10 minutes

💰 Time saved: ~65 minutes!
```

---

## 🎯 Next Steps After Configuration

1. **Boot Kali VM**
   ```bash
   qm start 116
   ```

2. **Boot Wazuh Containers**
   ```bash
   pct start 250 251 252 253
   ```

3. **Verify Network**
   ```bash
   # From Proxmox host
   ping 10.0.0.2   # Kali
   ping 10.6.6.x   # SEC_EGRESS
   ping 10.9.9.x   # SEC_ISOLATED
   ```

4. **Deploy GOAD** (Optional)
   ```bash
   pct start 254
   # Follow GOAD setup guide
   ```

5. **Run Penetration Tests**
   ```bash
   # From Kali
   ssh root@10.0.0.2
   ```

6. **Monitor with Wazuh**
   ```
   https://10.0.0.X:443
   (Wazuh Dashboard - check web console for IP)
   ```

---

## 🔐 Security Reminders

⚠️ **Lab Environment Only**

- [ ] Change OPNsense root password after API configuration
- [ ] Change Wazuh admin password
- [ ] Consider disabling API after setup
- [ ] Review all firewall rules
- [ ] Test network isolation between subnets
- [ ] Use SSH keys instead of passwords
- [ ] Keep OPNsense updated

---

## 📚 Additional Resources

- **Full Guide**: `OPNSENSE-API-AUTOMATION-GUIDE.md`
- **Bash Automation**: `proxmox-lab-automation-opnsense.sh`
- **Quick Reference**: `QUICK-REFERENCE-OPNSENSE.md`
- **OPNsense Docs**: https://docs.opnsense.org/
- **API Client GitHub**: https://github.com/O-X-L/opnsense-api-client

---

**Version**: 1.0  
**Last Updated**: 2025-12-01  
**Status**: Production Ready  

---

**Questions?**

1. Check `OPNSENSE-API-AUTOMATION-GUIDE.md` for detailed troubleshooting
2. Review `/root/opnsense_config.log` for error details
3. Consult OPNsense documentation
4. Check OPNsense API client GitHub issues

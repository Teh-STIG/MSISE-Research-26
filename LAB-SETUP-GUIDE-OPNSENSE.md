# Proxmox Lab Automation - OPNsense Edition Setup Guide

## Overview - Why OPNsense Instead of pfSense?

pfSense CE no longer provides publicly accessible ISO downloads. **OPNsense** is the perfect replacement:

| Feature | pfSense | OPNsense |
|---------|---------|----------|
| **ISO Downloads** | ❌ Requires account | ✅ Publicly available |
| **Interface Names** | em0, em1 | em0, em1 |
| **VLAN Support** | ✅ Full support | ✅ Full support |
| **Firewall Rules** | ✅ PF-based | ✅ PF-based |
| **DHCP Server** | ✅ Yes | ✅ Yes |
| **Performance** | High | High |
| **Community** | Large | Growing |
| **API** | REST API | REST API |

### OPNsense Advantages
- **Open Download**: ISO freely available from multiple mirrors
- **Active Development**: Regular updates and security patches
- **Similar Interface**: Familiar firewall rule structure
- **Identical Functionality**: Works exactly like pfSense for this lab

## Lab Components

This guide configures:

- **OPNsense Firewall** - Segmented network with VLANs (replaces pfSense)
- **Kali Linux** - Penetration testing platform
- **OWASP Juice Shop** - Vulnerable web application
- **Wazuh SIEM** - Security information and event management
- **Network IDS** - Suricata + Zeek intrusion detection
- **GOAD Provisioning** - Vulnerable Active Directory environment

## Prerequisites

### System Requirements
- Proxmox VE 6.17.2 or later
- Debian 11+ (Bookworm for Proxmox 8)
- 64 GB RAM (32 GB minimum)
- 500 GB SSD (1 TB recommended)
- LVM or ZFS storage
- Single or dual gigabit network interface

### Network Requirements
- Home router with DHCP and port forwarding capability
- Static DHCP reservations support
- Access to download ISOs (~150 GB total)

## Quick Start

### 1. Download the OPNsense Automation Script

```bash
# On your Proxmox host
cd /root
chmod +x proxmox-lab-automation-opnsense.sh
```

### 2. Customize Configuration

Edit the script and update these critical variables:

```bash
# Network Configuration - MUST MATCH YOUR ENVIRONMENT
VMBR0_INTERFACE="enp0s31f6"        # Your physical NIC
HOME_NETWORK="172.16.1.0/24"       # Your home router subnet
HOME_ROUTER_IP="172.16.1.1"        # Your home router IP
HYPERVISOR_IP="172.16.1.16"        # Your Proxmox host IP

# Storage Configuration
STORAGE_TARGET="local-lvm"         # Your storage target
GUEST_STORAGE="local-lvm"          # Guest disk storage

# OPNsense ISO (automatically downloaded)
OPNSENSE_ISO_URL="https://mirror.ams.evolix.net/opnsense/releases/24.7/OPNsense-24.7.3-dvd-amd64.iso.bz2"
```

### 3. Run in Dry-Run Mode (Recommended)

```bash
# See what changes would be made
./proxmox-lab-automation-opnsense.sh --dry-run --verbose
```

### 4. Execute Full Setup

```bash
# Run the complete setup
./proxmox-lab-automation-opnsense.sh --verbose

# Or skip certain components
./proxmox-lab-automation-opnsense.sh --skip-wazuh --verbose
```

## OPNsense Initial Configuration

After the OPNsense VM boots:

### Step 1: First Boot

1. Boot OPNsense from ISO
2. Accept default installation to disk
3. Choose swap size: **2 GB** (standard)
4. System will install and reboot
5. Remove ISO from VM

### Step 2: Console Configuration (Option 2)

After boot, you'll see a console menu. Select **Option 2** to configure interfaces:

```
1. em0 - WAN Interface
   - Configure IPv4: DHCP
   - Accept defaults for IPv6

2. em1 - LAN Interface  
   - Configure IPv4: 10.0.0.1/24
   - DHCP: Enable
   - DHCP Range: 10.0.0.11 - 10.0.0.244
```

### Step 3: Web Console Access

```
URL: https://10.0.0.1:443
Username: root
Password: opnsense
```

### Step 4: Configure VLAN Interfaces

**In OPNsense Web UI:**

Navigate to **Interfaces > Assignments > VLANs**

#### Add VLAN 666 (SEC_EGRESS)
```
Parent: em1
VLAN tag: 666
Description: SEC_EGRESS
Priority: 0
```

**Then** go to **Interfaces > Assignments** and click **+** to add new interface:
```
Name: OPT1
Assign to: em1.666

Click OPT1 to configure:
├── Enable Interface
├── IPv4: 10.6.6.1/24
├── IPv6: None
└── DHCP Server:
    ├── Enable
    ├── Range: 10.6.6.11 - 10.6.6.244
```

#### Add VLAN 999 (SEC_ISOLATED)
```
Parent: em1
VLAN tag: 999
Description: SEC_ISOLATED
Priority: 0
```

**Then** add new interface:
```
Name: OPT2
Assign to: em1.999

Click OPT2 to configure:
├── Enable Interface
├── IPv4: 10.9.9.1/24
├── IPv6: None
└── DHCP Server:
    ├── Enable
    ├── Range: 10.9.9.11 - 10.9.9.244
```

## Firewall Rules Configuration

### Step 1: Create Aliases

**Firewall > Aliases**

#### RFC1918 Alias (Private Networks)
```
Name: RFC1918
Description: Private IP ranges
Networks:
  - 10.0.0.0/8
  - 172.16.0.0/12
  - 192.168.0.0/16
```

#### Kali Alias
```
Name: Kali
Description: Kali penetration testing VM
Host: 10.0.0.2
```

### Step 2: Configure WAN Rules

**Firewall > Rules > WAN**

#### Allow Home Network to Internal LAN
```
Action: Pass
Protocol: IPv4
Source: 172.16.1.0/24 (Your home network)
Destination: 10.0.0.0/24 (Internal LAN)
Description: Allow home network to internal lab
```

### Step 3: Configure SEC_EGRESS Rules

**Firewall > Rules > OPT1 (SEC_EGRESS)**

#### Allow to Gateway
```
Action: Pass
Protocol: IPv4+IPv6
Source: 10.6.6.0/24
Destination: 10.0.0.1
Description: Allow SEC_EGRESS to gateway
```

#### Allow to Kali
```
Action: Pass
Protocol: IPv4+IPv6
Source: 10.6.6.0/24
Destination: 10.0.0.2
Description: Allow SEC_EGRESS to Kali
```

#### Allow Internet Access (Non-RFC1918)
```
Action: Pass
Protocol: IPv4
Source: 10.6.6.0/24
Destination: !RFC1918
Description: Allow SEC_EGRESS to internet
```

#### Block Everything Else
```
Action: Block
Protocol: IPv4+IPv6
Source: 10.6.6.0/24
Description: Block all other traffic
```

### Step 4: Configure SEC_ISOLATED Rules

**Firewall > Rules > OPT2 (SEC_ISOLATED)**

#### Allow DNS
```
Action: Pass
Protocol: TCP/UDP
Source: 10.9.9.0/24
Destination: 10.0.0.1
Destination Port: 53
Description: Allow DNS
```

#### Allow to Kali Only
```
Action: Pass
Protocol: IPv4+IPv6
Source: 10.9.9.0/24
Destination: 10.0.0.2
Description: Allow SEC_ISOLATED to Kali only
```

#### Block Everything Else
```
Action: Block
Protocol: IPv4+IPv6
Source: 10.9.9.0/24
Description: Block all other traffic from isolated
```

### Step 5: Floating Rules

**Firewall > Rules > Floating**

#### Block Firewall Access from Security Subnets
```
Direction: in
Action: Block
Interface: OPT1, OPT2
Protocol: TCP
Destination Port: 443, 80, 22
Description: Block firewall admin access from security nets
```

## OPNsense vs pfSense - Equivalence Chart

| Task | pfSense | OPNsense |
|------|---------|----------|
| Access Web UI | `https://ip:443` | `https://ip:443` |
| Default User | admin | root |
| Default Pass | pfsense | opnsense |
| Configure Interfaces | Interfaces > Assignments | Interfaces > Assignments |
| Create VLANs | Interfaces > VLANs | Interfaces > Assignments > VLANs |
| Firewall Rules | Firewall > Rules | Firewall > Rules |
| DHCP Server | Services > DHCP Server | Services > DHCP |
| DNS Resolver | Services > DNS Resolver | Services > Unbound DNS |
| SSH into Device | ssh admin@ip | ssh root@ip |

## Network Architecture

```
Internet / ISP
     |
Home Router (172.16.1.0/24)
     |
Proxmox Host (172.16.1.16) - lapprox.home.lab
     |
     +-- vmbr0 (Open vSwitch - Production)
     |    |
     |    +-- OPNsense WAN (em0) -> DHCP from router
     |    |
     |    +-- Wazuh containers (management interface)
     |    |
     |    +-- NIDS (sniff-prod interface)
     |
     +-- vmbr1 (Open vSwitch - Internal/Security)
          |
          +-- OPNsense LAN (em1)
          |
          +-- em1.666 (VLAN 666) -> SEC_EGRESS (10.6.6.0/24)
          |    |
          |    +-- Juice Shop (internet access)
          |    +-- Other non-isolated targets
          |
          +-- em1.999 (VLAN 999) -> SEC_ISOLATED (10.9.9.0/24)
               |
               +-- Juice Shop (isolated, Kali only)
               +-- Isolated targets
```

## DHCP Reservations in OPNsense

**System > Network > DHCP Server > [Interface]**

For each interface, set static DHCP reservations:

```
LAN (10.0.0.0/24):
├── Kali VM: 10.0.0.2 (MAC: from VM 116)
└── Reserve: 10.0.0.11 - 10.0.0.244 for DHCP

SEC_EGRESS (10.6.6.0/24):
├── Juice Shop: 10.6.6.x (MAC: from CT 200)
└── Reserve: 10.6.6.11 - 10.6.6.244 for DHCP

SEC_ISOLATED (10.9.9.0/24):
└── Reserve: 10.9.9.11 - 10.9.9.244 for DHCP
```

## OPNsense vs pfSense Interface Naming

Key difference: **OPNsense uses the same interface naming as FreeBSD base**

| Function | pfSense | OPNsense |
|----------|---------|----------|
| WAN interface | vtnet0 (Proxmox) or em0 (bare metal) | em0 |
| LAN interface | vtnet1 (Proxmox) or em1 (bare metal) | em1 |
| VLAN syntax | em1_666 (underscore) | em1.666 (dot) |
| SSH access | ssh admin@ip | ssh root@ip |

**Important**: In Proxmox, OPNsense still uses `virtio` (em0, em1) naming internally because we're using QEMU.

## Troubleshooting OPNsense Setup

### OPNsense Won't Boot

```bash
# Check if ISO exists
ls -lah /var/lib/vz/template/iso/opnsense*

# If missing, re-download
wget -O /var/lib/vz/template/iso/opnsense-24.7.3-dvd-amd64.iso.bz2 \
  https://mirror.ams.evolix.net/opnsense/releases/24.7/OPNsense-24.7.3-dvd-amd64.iso.bz2
bunzip2 -f /var/lib/vz/template/iso/opnsense-24.7.3-dvd-amd64.iso.bz2

# Reset VM boot order
qm set 100 --boot order=d
qm start 100
```

### Can't Access Web Console

```bash
# SSH into OPNsense (em0 is WAN, DHCP)
ssh root@<opnsense-wan-ip>

# Check if web service is running
ps aux | grep lighttpd

# Restart if needed
service lighttpd restart

# Check firewall isn't blocking (WAN blocks by default)
```

### Interfaces Not Getting DHCP

```bash
# From Proxmox host, SSH to OPNsense em1 interface
ssh -o StrictHostKeyChecking=no root@10.0.0.1

# Check interface status
ifconfig em0
ifconfig em1

# Restart dhclient if needed
dhclient -r em0
dhclient em0
```

### VLANs Not Working

```bash
# Verify VLAN interfaces created
ifconfig | grep em1

# Should see:
# em1.666
# em1.999

# If not, check OPNsense web UI for errors
# Interfaces > Assignments > VLANs
```

## SSH Access to OPNsense

### From Home Network

```bash
# Get OPNsense WAN IP (DHCP from home router)
# Then SSH using root credentials
ssh root@<opnsense-wan-ip>

# Or from Proxmox host
ssh root@172.16.1.2  # Assuming static DHCP reservation
```

### From Behind OPNsense

```bash
# Add static route in home router
Destination: 10.0.0.0/24
Gateway: 172.16.1.2 (OPNsense WAN)

# Then SSH directly
ssh root@10.0.0.1
```

## OPNsense Management Best Practices

### 1. Change Default Password

**System > Settings > Administration**

```
New Password: [Change from 'opnsense']
Confirm: [Enter again]
```

### 2. Enable SSH

**System > Settings > Administration**

```
SSH: ☑ Enable (enabled by default)
Permit Root Login: ☑ (for lab only)
```

### 3. Set NTP Server

**System > Settings > Administration**

```
NTP Server: pool.ntp.org
```

### 4. Configure DNS Forwarder

**Services > Unbound DNS > General Settings**

```
Enable: ☑
Listen Interfaces: All
```

## OPNsense Documentation References

- **Official Docs**: https://docs.opnsense.org/
- **Firewall Rules**: https://docs.opnsense.org/manual/firewall.html
- **VLAN Configuration**: https://docs.opnsense.org/manual/how-tos/vlan.html
- **DHCP Server**: https://docs.opnsense.org/manual/dhcp.html
- **Download Mirror**: https://mirror.ams.evolix.net/opnsense/releases/

## Migration from pfSense (if you were using it)

If you previously had a pfSense setup, migration is straightforward:

1. **Export pfSense Configuration**: 
   - Diagnostics > Backup & Restore > Backup

2. **Import to OPNsense**:
   - System > Configuration > Restore

3. **Update Interface Names** (if needed):
   - pfSense: em1_666 → OPNsense: em1.666
   - Firewall rules may need minor adjustments

## Next Steps After Automation

1. ✅ Run `proxmox-lab-automation-opnsense.sh --dry-run -v`
2. ✅ Review generated configuration files
3. ✅ Customize script variables for your environment
4. ✅ Run `proxmox-lab-automation-opnsense.sh -v`
5. ⏳ Boot OPNsense and complete initial configuration
6. ⏳ Configure firewall rules as documented above
7. ⏳ Set up DHCP reservations
8. ⏳ Boot remaining VMs and containers
9. ⏳ Deploy Wazuh and GOAD

## Summary

**OPNsense is a drop-in replacement for pfSense** with these advantages:

✅ Public ISO downloads available  
✅ No registration required  
✅ Same firewall functionality  
✅ Compatible rule structures  
✅ Active development and updates  
✅ Growing community support  

The automation script now uses OPNsense exclusively, automatically downloading from public mirrors instead of requiring pfSense account access.

---

**Last Updated**: 2025-12-01  
**Version**: 2.0 (OPNsense Edition)

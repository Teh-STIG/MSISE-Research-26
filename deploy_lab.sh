#!/bin/bash

################################################################################
# Proxmox Cybersecurity Lab Automation Script
# 
# This script automates the creation and configuration of a complete cybersecurity
# lab environment on Proxmox VE based on documented procedures from:
# https://docs.technotim.live/posts/proxmox-lab/
#
# Lab Components:
# - OPNsense Firewall with VLANs (replaces pfSense)
# - Kali Linux Penetration Testing Platform
# - OWASP Juice Shop (Dockerized)
# - Wazuh SIEM with Network Intrusion Detection System (NIDS)
# - Game of Active Directory (GOAD) v3
# - Supporting infrastructure (containers, networking, storage)
#
# Author: Generated from lab documentation
# Version: 2.0 (OPNsense Edition)
# Last Updated: 2025-12-01
################################################################################

set -euo pipefail

################################################################################
# CONFIGURATION VARIABLES - CUSTOMIZE FOR YOUR ENVIRONMENT
################################################################################

# Proxmox Node Configuration
#PROXMOX_HOST="127.0.0.1"                    # Proxmox host IP
PROXMOX_NODE="proxmox"                       # Proxmox node hostname
#PVE_USERNAME="root@pam"                      # Proxmox API user
#PVE_TOKEN_SECRET=""                          # Optional: API token secret
#PROXMOX_PORT="8006"

# General Config Settings
CONFIG_DIR="/root/lab-config"
SSH_CYBER_KEY="/root/.ssh/cyber.range"
ROOTDOMAIN="themyers.dev"

if [ ! -d "$CONFIG_DIR" ]; then
    echo -e "Creating Config Folder for first time"
    mkdir $CONFIG_DIR
else
    echo -e "Config folder already existed, clearing it out so we have a clean slate"
    rm -rf $CONFIG_DIR
    mkdir $CONFIG_DIR
fi

#NOT NEEDED
# Network Configuration
#HOME_NETWORK="172.16.1.0/24"                 # Home router network
#HOME_ROUTER_IP="172.16.1.1"                  # Home router gateway
#HOME_DOMAIN="home.lab"                       # Home domain name
#HYPERVISOR_IP="172.16.1.16"                  # Proxmox hypervisor IP
#HYPERVISOR_HOSTNAME="lapprox.home.lab"       # Hypervisor hostname

# Virtual Network Configuration
#VMBR0_INTERFACE="enp0s31f6"                  # Physical NIC for vmbr0
#VMBR0_IP="172.16.1.16"                       # Management IP
#VMBR0_NETMASK="24"

NODE_NAME="pve2"
LVM_STORAGE="local-lvm"

# Physical uplink and main bridges
#UPLINK_IFACE="enp4s0f0"
#Establishes the primary uplink interface dynamically by checking for the second interface (i.e NOT the loopback interface) that is UP and using that as the uplink.
#UPLINK_IFACE=$(ip -br link show | grep "UP" | awk 'NR==2 {print $1}')
#WAN_BRIDGE="vmbr0"
LAN_BRIDGE="vmbr1"

# VLANs (tagged on LAN_BRIDGE)

VLAN_SEC=48
VLAN_CORP=80
VLAN_EGRESS=666
VLAN_GOAD=888
VLAN_ISOLATED=999

# OPNsense Configuration (replaces pfSense)
OPNSENSE_VMID="9001"
OPNSENSE_MEMORY="8192"
OPNSENSE_CORES="4"
OPNSENSE_STORAGE="10"
OPNSENSE_BRIDGE="vmbr0"
OPNSENSE_IP="10.0.0.1/24"
#OPNSENSE_WAN_VLAN_TAG="0"                    # No tag for WAN (native)
#OPNSENSE_LAN_VLAN="1"
#OPNSENSE_ADMIN_PASS="opnsense"               # CHANGE THIS!
OPNSENSE_HOSTNAME="opnsense-sec"
#OPNSENSE_DOMAIN="cyber.range"
#OPNSENSE_ISO_URL="https://pkg.opnsense.org/releases/25.7/OPNsense-25.7-dvd-amd64.iso.bz2"
#OPNSENSE_ISO_PATH="/var/lib/vz/template/iso/opnsense-25.7-dvd-amd64.iso"

# Network Subnets
LAN_SUBNET="10.0.0.0/24"                     # Default LAN
LAN_GATEWAY="10.0.0.1"
SEC_EGRESS_SUBNET="10.6.6.0/24"              # Egress subnet (internet access)
SEC_EGRESS_GATEWAY="10.6.6.1"
SEC_ISOLATED_SUBNET="10.9.9.0/24"            # Isolated subnet (no internet)
SEC_ISOLATED_GATEWAY="10.9.9.1"
AD_LAB_SUBNET="192.168.10.0/24"              # Active Directory lab
AD_LAB_GATEWAY="192.168.10.1"

# Storage Configuration
STORAGE_TARGET="local-lvm"                   # Default storage target
#GUEST_STORAGE="local-lvm"                    # Guest disk storage
#ISO_STORAGE="local"                          # ISO storage location

# Resource Pool
#RESOURCE_POOL="GOAD"                         # Resource pool for GOAD lab

# Kali Configuration
#KALI_VMID="9004"
#KALI_HOSTNAME="kali"
#KALI_IP="10.0.0.4/24"
#KALI_GATEWAY="10.0.0.1"
#KALI_DNS="10.0.0.1"

# Juice Shop Configuration
#JUICESHOP_HOSTNAME="juiceshop"
#JUICESHOP_CTID="9901"
#JUICESHOP_MEMORY="2048"
#JUICESHOP_CORES="2"
#JUICESHOP_STORAGE="20"
#JUICESHOP_VLAN="999"                         # Isolated VLAN

# OSSIEM Configuration
OSSIEM_HOSTNAME="ossiem"
OSSIEM_VMID="9002"
OSSIEM_MEMORY="10240"
OSSIEM_CORES="8"
OSSIEM_STORAGE="100"
#OSSIEM_IP="10.0.0.2"
#OSSIEM_IP="192.168.0.252"
OSSIEM_BRIDGE="vmbr0"
OSSIEM_VIRT_CONFIG="$CONFIG_DIR/ossiem.range"

# TacticalRMM Configuration
TACRMM_HOSTNAME="tacticalrmm"
TACRMM_VMID="9003"
TACRMM_MEMORY="4096"
TACRMM_CORES="4"
TACRMM_STORAGE="100"
TACRMM_IP="10.0.0.3"
#TACRMM_IP="192.168.0.253"
TACRMM_BRIDGE="vmbr0"
TACRMM_VIRT_CONFIG="$CONFIG_DIR/tacrmm.range"

# NIDS Configuration

NIDS_HOSTNAME="nids-node"
NIDS_CTID="253"
NIDS_MEMORY="4096"
NIDS_CORES="4"
NIDS_STORAGE="50"

# Provisioning Container for GOAD
PROVISIONING_CTID="254"
PROVISIONING_HOSTNAME="provisioning"
PROVISIONING_MEMORY="2048"
PROVISIONING_CORES="2"
PROVISIONING_STORAGE="30"

# Windows Template IDs (from Packer builds)
WINDOWS_SERVER_2019_TEMPLATE="100"
WINDOWS_SERVER_2016_TEMPLATE="102"

# ISOs and Downloads
KALI_QCOW2_URL="https://cdimage.kali.org/kali-2025.3/kali-linux-2025.3-qemu-amd64.7z"
DEBIAN_13_LXC_TEMPLATE="debian-13-standard_13.1-2_amd64.tar.zst"
DEBIAN_QCOW2_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-nocloud-amd64.qcow2"

# Flags
SKIP_NETWORK_CONFIG=false
SKIP_OPNSENSE=false
SKIP_KALI=false
SKIP_JUICE_SHOP=false
SKIP_WAZUH=false
SKIP_TACRMM=false
SKIP_GOAD=false
DRY_RUN=false
VERBOSE=false
SSH_CYBER_KEY="/root/.ssh/cyber.range"

################################################################################
# LOGGING AND UTILITY FUNCTIONS
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

log_info() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

log_section() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $*${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Execute command with logging
execute() {
    if [ "$VERBOSE" = true ]; then
        log "Executing: $*"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_warn "DRY RUN: $*"
        return 0
    fi
    
    if ! output=$("$@" 2>&1); then
        log_error "Command failed: $*"
        log_error "Output: $output"
        return 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        log_info "Command completed successfully"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

################################################################################
# VALIDATION FUNCTIONS
################################################################################

validate_environment() {
    log_section "Validating Environment"
    
    local errors=0
    
    # Check if running on Proxmox
    if ! command_exists pveam; then
        log_error "This script must be run on a Proxmox VE node"
        ((errors++))
    fi
    
    # Check required commands
    local required_cmds=("curl" "wget" "ssh" "qm" "pct" "pvesh" "git" "p7zip")
    for cmd in "${required_cmds[@]}"; do
        if ! command_exists "$cmd"; then
            log_error "Required command not found: $cmd"
            ((errors++))
        fi
    done
    
    if [ $errors -gt 0 ]; then
        log_error "Environment validation failed with $errors error(s)"
        exit 1
    fi
    
    log_info "Environment validation passed"
}

################################################################################
# ISO AND TEMPLATE MANAGEMENT
################################################################################

download_isos() {
    log_section "Downloading ISOs and Templates"
    
    local iso_dir="/var/lib/vz/template/iso"
    
    # Create ISO directory
    execute mkdir -p "$iso_dir"
    
    #Handled by the Opnsense-vm.sh script, but leaving this here in case we want to download it manually in the future.
    # Download OPNsense ISO
    #if [ ! -f "$OPNSENSE_ISO_PATH" ]; then
    #    log "Downloading OPNsense ISO..."
    #    log "If this fails, please check the URL https://pkg.opnsense.org/releases/mirror/, grab the latest version link (OPNsense-XX.X-dvd-amd64.iso.bz2) and change it in the script!"
    #    execute wget -O "$OPNSENSE_ISO_PATH.bz2" "$OPNSENSE_ISO_URL"
    #    execute bunzip2 -f "$OPNSENSE_ISO_PATH.bz2" 
    #    log_info "OPNsense ISO downloaded and extracted"
    #else
    #    log_info "OPNsense ISO already exists"
    #fi
    
    # Download Kali QCOW2 if needed
    local kali_path="/var/lib/vz/images/kali-linux-2025.3-qemu-amd64.qcow2"
        local kali_zip="/var/lib/vz/images/kali-linux-2025.3-qemu-amd64.7z"
    if [ ! -f "$kali_path" ]; then
        log "Downloading Kali Linux QCOW2 image..."
        log "If this fails, please check the URL https://cdimage.kali.org/current/ and grab the latest version link (kali-linux-XXXXXX-qemu-amd64.7z) and change it in the script!"
        execute wget -O "$kali_zip" "$KALI_QCOW2_URL"
                execute 7z x "$kali_zip" -o/var/lib/vz/images/
        log_info "Kali Linux image downloaded and unzipped"
    else
        log_info "Kali Linux image already exists"
    fi
    

        # Download Debian13 QCOW2 if needed
    local deb13_path="/var/lib/vz/images/debian-13-nocloud-amd64.qcow2"
    if [ ! -f "$deb13_path" ]; then
        log "Downloading Debian13 QCOW2 image..."
        execute wget -O "$deb13_path" "$DEBIAN_QCOW2_URL"
        log_info "Debian13 image downloaded and unzipped"
    else
        log_info "Debian13 image already exists"
    fi

}

################################################################################
# CONFIGURE CYBER LAB NETWORKING
################################################################################

# Helper: append a block to /etc/network/interfaces if not present
append_if_missing() {
    local pattern="$1"
    local block="$2"
    if ! grep -q "$pattern" /etc/network/interfaces; then
        printf "\n%s\n" "$block" >> /etc/network/interfaces
        echo "Added network block for pattern: $pattern"
    else
        echo "Block with pattern '$pattern' already present, skipping."
    fi
}

configure_networking() {
    echo "=== Configuring networking ==="

    #Let's not mess with the WAN bridge for now, as it may disrupt connectivity to the Proxmox host. We'll focus on the internal LAN bridge and VLANs.
    # WAN bridge vmbr0
    #WAN_BLOCK="auto ${WAN_BRIDGE}
    #iface ${WAN_BRIDGE} inet manual
    #bridge_ports ${UPLINK_IFACE}
    #bridge_stp off
    #bridge_fd 0"

    #append_if_missing "iface ${WAN_BRIDGE} inet" "$WAN_BLOCK"

    # Internal bridge vmbr1 (no IP, used as pure switch)
    LAN_BLOCK="auto ${LAN_BRIDGE}
    iface ${LAN_BRIDGE} inet manual
    bridge_ports none
    bridge_stp off
    bridge_fd 0"

    append_if_missing "iface ${LAN_BRIDGE} inet" "$LAN_BLOCK"

    # VLAN sub-interfaces on LAN_BRIDGE
    for vlan in "$VLAN_GOAD" "$VLAN_SEC" "$VLAN_CORP" "$VLAN_EGRESS" "$VLAN_ISOLATED"; do
        local iface="vmbr1.${vlan}"
        VLAN_BLOCK="auto ${iface}
        iface ${iface} inet manual
        vlan_raw_device ${LAN_BRIDGE}"
        append_if_missing "iface ${iface} inet" "$VLAN_BLOCK"
    done

    echo "Reloading network configuration (this may disrupt connectivity)..."
    ifreload -a || echo "Warning: ifreload -a returned non-zero; verify /etc/network/interfaces."
}

################################################################################
# VM CREATION FUNCTIONS
################################################################################

create_opnsense_vm() {
    # Check if the user opted to skip OPNsense via the --skip-opnsense flag
    if [[ "${SKIP_OPNSENSE}" == "true" ]]; then
        log "Skipping OPNsense VM creation as requested."
        return 0
    fi

    execute wget https://raw.githubusercontent.com/Teh-STIG/MSISE-Research-26/main/opnsense-vm.sh -O $CONFIG_DIR/opnsense-vm.sh

    execute chmod +x $CONFIG_DIR/opnsense-vm.sh

    log "Deploying OPNsense Virtual Machine"
    sleep 5
    $CONFIG_DIR/opnsense-vm.sh -v $OPNSENSE_VMID -d $OPNSENSE_STORAGE -n $OPNSENSE_HOSTNAME -c $OPNSENSE_CORES -r $OPNSENSE_MEMORY -b $OPNSENSE_BRIDGE 

    log "WHEW, that was a lot!\n Now that the OPNsesne VM is deployed, let's give it 45 seconds to start up before we check to see if the IP has changed..."

    sleep 45

    OPNSENSE_NET=$(qm guest cmd $OPNSENSE_VMID network-get-interfaces | grep -oP '"ip-address" : "\K[^"]*' | grep 192)

    if ! [ "$OPNSENSE_IP" = "$OPNSENSE_NET" ]; then
            log_warn "Oops, looks like the IP changed to $OPNSENSE_NET but thats ok, we've accounted for the change"
    fi
}

create_tacrmm_vm() {
    log_section "Creating Tactical RMM Virtual Machine"
    
    if [ "$SKIP_TACRMM" = true ]; then
        log_warn "Skipping Tactical RMM VM Creation"
        return 0
    fi
 
cat > "$TACRMM_VIRT_CONFIG" <<EOF
mkdir /etc/letsencrypt/live/${ROOTDOMAIN}
copy-in /etc/letsencrypt/live/${ROOTDOMAIN}:/etc/letsencrypt/live/
EOF


    #Step 1: Pull TacticalRMM DockerCompose/.env and prepare the repo before transfering it to the VM

        #log "Pulling TacticalRMM files local..."

        #execute mkdir $CONFIG_DIR/TACRMM
        #execute wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/docker/docker-compose.yml -O $CONFIG_DIR/TACRMM/docker-compose.yml
        #execute wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/docker/.env.example -O $CONFIG_DIR/TACRMM/.env

        #log "Modifying the .env file for TacticalRMM with your randomly generated credentials"

        #execute sed -i "s/\(_PASS=\).*/\1$CYBER_CREDS/" $CONFIG_DIR/TACRMM/.env
        #execute sed -i "s/^MONGODB_PASSWORD=.*/MONGODB_PASSWORD=$DB_CREDS/" $CONFIG_DIR/TACRMM/.env
        #execute sed -i "s/^POSTGRES_PASS=.*/POSTGRES_PASS=$DB_CREDS/" $CONFIG_DIR/TACRMM/.env
        #execute sed -i "s/\bexample.com\b/$ROOTDOMAIN/g" $CONFIG_DIR/TACRMM/.env
        #echo "CERT_PUB_KEY=$(base64 -w 0 /etc/letsencrypt/live/${ROOTDOMAIN}/fullchain.pem)" >> $CONFIG_DIR/TACRMM/.env
        #echo "CERT_PRIV_KEY=$(base64 -w 0 /etc/letsencrypt/live/${ROOTDOMAIN}/privkey.pem)" >> $CONFIG_DIR/TACRMM/.env

        #STUFF TO DO ON THE ACTUAL VM AFTER PROVISIONED

        # Deploy Wazuh VM

        execute wget https://raw.githubusercontent.com/Teh-STIG/MSISE-Research-26/main/debian12_vm.sh -O $CONFIG_DIR/debian12_vm.sh

        execute chmod +x $CONFIG_DIR/debian12_vm.sh

        log "Deploying TacticalRMM Virtual Machine"
        sleep 5
        $CONFIG_DIR/debian12_vm.sh -v $TACRMM_VMID -d $TACRMM_STORAGE -n $TACRMM_HOSTNAME -c $TACRMM_CORES -r $TACRMM_MEMORY -b $TACRMM_BRIDGE -i $TACRMM_VIRT_CONFIG

        log "WHEW, that was a lot!\n Now that the VM is deployed, let's give it 25 seconds to start up before we check to see if the IP has changed..."

        sleep 25

        TACRMM_NET=$(qm guest cmd $TACRMM_VMID network-get-interfaces | grep -oP '"ip-address" : "\K[^"]*' | grep 192)

        if ! [ "$TACRMM_IP" = "$TACRMM_NET" ]; then
                log_warn "Oops, looks like the IP changed to $TACRMM_NET but thats ok, we've accounted for the change"
        fi

        log_section "Configuring TacticalRMM VM then installing the TacticalRMM software... Please wait"
        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$TACRMM_NET "apt update;apt install -y wget curl sudo ufw;apt -y upgrade"
        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$TACRMM_NET "useradd -m -G sudo -s /bin/bash tactical"
        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$TACRMM_NET "echo -e '$CYBER_CREDS\n$CYBER_CREDS' | passwd tactical"
        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$TACRMM_NET "su -c 'wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/install.sh -O ~/install.sh' tactical"
        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$TACRMM_NET "chmod +x /home/tactical/install.sh"
        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$TACRMM_NET "echo 'tactical ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers"
        ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$TACRMM_NET "echo -e 'api.$ROOTDOMAIN\nrmm.$ROOTDOMAIN\nmesh.$ROOTDOMAIN\n$ROOTDOMAIN\nadmin@$ROOTDOMAIN\ny' | su -c '/home/tactical/install.sh --insecure' tactical"

        sleep 5 

        log_section "You should be able to log into the TacticalRMM at: https://$TACRMM_NET with the password: ${CYBER_CREDS}"

}


create_wazuh_infrastructure() {
    log_section "Creating Wazuh SIEM Infrastructure"
    
    if [ "$SKIP_WAZUH" = true ]; then
        log_warn "Skipping Wazuh infrastructure"
        return 0
    fi
 
cat > "$OSSIEM_VIRT_CONFIG" <<EOF
mkdir /opt/OSSIEM
copy-in ${CONFIG_DIR}/OSSIEM:/opt/
EOF

        # Configure the OSSIEM services before transfering and starting
        # https://github.com/socfortress/OSSIEM?tab=readme-ov-file#pre-deployment

        #Step 1: Clone github repo locally and prepare the repo before transfering it to the VM

        log "Cloning OSSIEM Repo locally..."

        execute git clone https://github.com/socfortress/OSSIEM.git $CONFIG_DIR/OSSIEM

        log "Modifying the .env and docker-compose.yml file with your randomly generated credentials"

        execute sed -i "s/\(_PASSWORD=\).*/\1$CYBER_CREDS/" $CONFIG_DIR/OSSIEM/.env
        execute sed -i "/_PASSWORD=\${/!s/\(_PASSWORD=\).*/\1$CYBER_CREDS/" $CONFIG_DIR/OSSIEM/docker-compose.yml
        execute sed -i "s/^MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=$DB_CREDS/" $CONFIG_DIR/OSSIEM/.env
        execute sed -i "s/^MYSQL_PASSWORD=.*/MYSQL_PASSWORD=$DB_CREDS/" $CONFIG_DIR/OSSIEM/.env
        execute sed -i "s/^MINIO_ROOT_PASSWORD=.*/MINIO_ROOT_PASSWORD=$DB_CREDS/" $CONFIG_DIR/OSSIEM/.env

        # Deploy Wazuh VM

        execute wget https://raw.githubusercontent.com/Teh-STIG/MSISE-Research-26/main/docker_deb13_vm.sh -O $CONFIG_DIR/docker_deb13_vm.sh

        execute chmod +x $CONFIG_DIR/docker_deb13_vm.sh

        log "Deploying OSSIEM Virtual Machine"
        sleep 5
        $CONFIG_DIR/docker_deb13_vm.sh -v $OSSIEM_VMID -d $OSSIEM_STORAGE -n $OSSIEM_HOSTNAME -c $OSSIEM_CORES -r $OSSIEM_MEMORY -b $OSSIEM_BRIDGE -i $OSSIEM_VIRT_CONFIG

        log "WHEW, that was a lot!\n Now that the VM is deployed, let's give it 60 seconds to start up before we check to see if the IP has changed..."

        sleep 60

        OSSIEM_NET=$(qm guest cmd $OSSIEM_VMID network-get-interfaces | grep -oP '"ip-address" : "\K[^"]*' | grep 192)


        if ! [ "$OSSIEM_IP" = "$OSSIEM_NET" ]; then
                log_warn "Oops, looks like the IP changed to $OSSIEM_NET but thats ok, we've accounted for the change"
        fi

        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "sysctl -w vm.max_map_count=262144"

        #Step 2: Build the custom Wazuh-Manger
        #https://github.com/socfortress/OSSIEM/tree/main/wazuh/custom-wazuh-manager

                log "Building custom Wazuh-Manager, this may take a few minutes..."

                execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "cd /opt/OSSIEM/wazuh/custom-wazuh-manager/;docker build -t socfortress/wazuh-manager:4.9.0 --build-arg WAZUH_VERSION=4.9.0 --build-arg WAZUH_TAG_REVISION=1 ."

        #Step 3: Generate SSL Certs (comment out if you BYOC, just make sure to create a symlink to the correct folder)
        #From Github: Next you need to create, by whichever means you prefer, the required Wazuh SSL certs and place them in the wazuh/config/wazuh_indexer_ssl_certs directory. I'm providing the official Wazuh cert generating script under wazuh/generate-indexer-certs.yml. Instructions for for running this container/script can be found in the Official Wazuh Docker Repo and also under the specific subdirectory. Note: Also copy the root-ca.pem certificate into the graylog/ subdirectory as you will need it in a later step.

                log "Generating SSL Certs via Let's Encrypt"
                execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET " cd /opt/OSSIEM/wazuh/
                        docker compose -f ./generate-indexer-certs.yml run --rm generator"

                execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "cp /opt/OSSIEM/wazuh/config/wazuh_indexer_ssl_certs/root-ca.pem /opt/OSSIEM/graylog"

        #Step 4: Ensure Graylog has access to all files in the Graylog folder
                log "Fixing a few odds and ends like modifying the config files with your randomly generated password."
                execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "cd /opt/OSSIEM/graylog
                        chown 1100:1100 *"

                log_info "Wazuh infrastructure VM created! Now for the hard stuff...!"

        #Step 5: Bring up the OSSIEM Container stack up

        log_section "Go grab yourself a coffee, this is going to take a while!\n This step took approx. 1000 seconds on its own!"
        sleep 10
        log "Running Docker Compose for the OSSIEM stack now!"
        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "cd /opt/OSSIEM/;docker compose up -d"

        #Config Graylog SSL Certs

        log "Finalizing the internal docker container settings ..."

        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "docker exec -i graylog cp /opt/java/openjdk/lib/security/cacerts /usr/share/graylog/data/config/"

        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "docker exec -i graylog keytool -importcert -keystore /usr/share/graylog/data/config/cacerts -storepass changeit -alias wazuh_root_ca -file /usr/share/graylog/data/config/root-ca.pem -noprompt"

        log "Graylog reconfigured... restarting comtainer now"
        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "cd /opt/OSSIEM/;docker compose restart graylog"

        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "docker exec -i velociraptor ./velociraptor --config server.config.yaml config api_client --name admin --role administrator,api api.config.yaml"

        log "velociraptor reconfigured... restarting container now"
        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "cd /opt/OSSIEM/;docker compose restart velociraptor"


        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "docker exec -i wazuh.manager dnf install git -y"

        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET "docker exec -i wazuh.manager curl -so ~/wazuh_socfortress_rules.sh https://raw.githubusercontent.com/socfortress/OSSIEM/main/wazuh_socfortress_rules.sh"

        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET " docker exec -i wazuh.manager sed -i 's/^while true; do$/while false; do/' ~/wazuh_socfortress_rules.sh"

        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET 'docker exec -i wazuh.manager bash ~/wazuh_socfortress_rules.sh'


        log_section "This is an importan one! The following section containes your CoPilot 'admin' password, and once the container has been restarted it will not show this record again! I am saving this in a file called '.copilot.creds' for future use"

        execute ssh -o "ServerAliveInterval=60" -o "StrictHostKeyChecking=no" -t root@$OSSIEM_NET 'docker logs "$(docker ps --filter ancestor=ghcr.io/socfortress/copilot-backend:latest --format "{{.ID}}")" 2>&1 | grep "Admin user password" | cut -d "=" -f 4' > .copilot.creds

        sleep 5

        log_section "You should be able to log into the CoPilot at: https://$OSSIEM_NET with the password: ${cat .copilot.creds}"

}

################################################################################
# HELP AND USAGE
################################################################################

show_help() {
    cat <<EOF
Proxmox Cybersecurity Lab Automation Script (OPNsense Edition)

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Enable verbose output
    -d, --dry-run           Run in dry-run mode (no changes made)
    --skip-network          Skip network configuration
    --skip-opnsense         Skip OPNsense VM creation
    --skip-kali             Skip Kali Linux VM creation
    --skip-juice-shop       Skip OWASP Juice Shop container
    --skip-wazuh            Skip Wazuh SIEM infrastructure
    --skip-tacrmm           Skip Tactical RMM VM creation
    --skip-goad             Skip GOAD provisioning container
    --validate-only         Only validate environment

EXAMPLES:
    # Full lab setup with verbose output
    $0 -v

    # Dry run to see what would be done
    $0 --dry-run -v

    # Skip network config and only create VMs
    $0 --skip-network

    # Only validate environment
    $0 --validate-only

ENVIRONMENT VARIABLES:
    Edit variables at the top of the script to customize:
    - PROXMOX_NODE
    - STORAGE_TARGET
    - VMBR0_INTERFACE
    - And many more configuration options

REQUIREMENTS:
    - Proxmox VE 6.0+
    - Debian 11+
    - 64 GB+ RAM recommended
    - 500 GB+ SSD storage recommended
    - Network connectivity to download ISOs

DOCUMENTATION:
    See included configuration files in /root/lab-config/ after running
    OPNsense is now used instead of pfSense (publicly available downloads)

EOF
}

################################################################################
# MAIN EXECUTION
################################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-network)
                SKIP_NETWORK_CONFIG=true
                shift
                ;;
            --skip-opnsense)
                SKIP_OPNSENSE=true
                shift
                ;;
            --skip-kali)
                SKIP_KALI=true
                shift
                ;;
            --skip-juice-shop)
                SKIP_JUICE_SHOP=true
                shift
                ;;
            --skip-wazuh)
                SKIP_WAZUH=true
                shift
                ;;
            --skip-tacrmm)
                SKIP_TACRMM=true
                shift
                ;;
            --skip-goad)
                SKIP_GOAD=true
                shift
                ;;
            --validate-only)
                validate_environment
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

}

main() {
    log_section "Proxmox Cybersecurity Lab Automation (OPNsense Edition)"
    log "Lab Setup Utility v2.0"
    log "Start time: $(date)"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate environment
    validate_environment
    
    # Show configuration
    if [ "$VERBOSE" = true ]; then
        log_section "Configuration Summary"
        log "Proxmox Node: $PROXMOX_NODE"
        log "Storage: $STORAGE_TARGET"
        log "Firewall: OPNsense (replaces pfSense)"
        log "Dry Run: $DRY_RUN"
        log "Verbose: $VERBOSE"
    fi
    
    # Execute setup stages

        # Generate SSH Keys to use with the VMs
    if [ ! -f "$SSH_CYBER_KEY" ]; then
        log "Creating SSH Key for Cyber Rang "
        ssh-keygen -t ed25519 -C "admin@cyber.range" -f $SSH_CYBER_KEY -N '' -q
    else
        log_info "Cyber Range SSH key already exists"
    fi
 

        # Install dictionary incase it doesn't exist, then generate the cyber range generic password

        apt install wamerican

    if [ ! -f ".cyber.creds" ]; then
        log "Generating Random Password to use for all virtual hosts"
        log "The password will be saved on the PVE instance in /root/.cyber.creds"
        
        shuf -n3 /usr/share/dict/words | tr -cd '[:alpha:]\n' | awk 'BEGIN{s=".*"; d="0123456789"; srand()}{w=tolower($0); sub(/./, toupper(substr(w,1,1)), w); c=substr(s, int(rand()*length(s))+1, 1); n=substr(d, int(rand()*length(d))+1, 1);printf "%s%s%s", w, c, n}END{printf "\n"}' > .cyber.creds
        
        CYBER_CREDS="$(cat .cyber.creds)"
        export CYBER_CREDS
        log_section "Your Cyber Range Password is: " 
        cat .cyber.creds
        
        cat .cyber.creds | tr -cd '[:alnum:]\n' > .db.creds
        DB_CREDS="$(cat .db.creds)"
        export DB_CREDS
    else
        log_info "Cyber Range Creds file '.cyber.creds' already exists"
        CYBER_CREDS="$(cat .cyber.creds)"
        export CYBER_CREDS
        log_section "Your Cyber Range Password is: " 
        cat .cyber.creds

    fi

    if [ ! -f ".db.creds" ]; then
        cat .cyber.creds | tr -cd '[:alnum:]\n' > .db.creds
        export DB_CREDS="$(cat .db.creds)"
    else
        export DB_CREDS="$(cat .db.creds)"
    fi

        # Config/Run TacticalRMM from Docker
        #https://docs.tacticalrmm.com/install_docker/
        #echo "CERT_PUB_KEY=$(base64 -w 0 /etc/letsencrypt/live/${ROOTDOMAIN}/fullchain.pem)" >> .env
        #echo "CERT_PRIV_KEY=$(base64 -w 0 /etc/letsencrypt/live/${ROOTDOMAIN}/privkey.pem)" >> .env


        download_isos
        configure_networking
        create_opnsense_vm
        #create_tacrmm_vm
        #create_wazuh_infrastructure

        log_section "Setup Complete"
    log_info "Lab environment setup completed successfully!"
    log ""
    log "Next steps:"
    log "1. Boot OPNsense VM and complete initial configuration"
    log "2. Configure firewall rules per documentation"
    log "3. Boot remaining VMs and containers"
    log "4. Run Wazuh setup scripts (manual for now)"
    log "5. Deploy GOAD Active Directory lab using provisioning container"
    log ""
    log "Configuration files: /root/lab-config/"
    log "OPNsense Documentation: https://docs.opnsense.org/"
    log "Original Documentation: https://docs.technotim.live/posts/proxmox-lab/"
    log ""
    log "End time: $(date)"
}

# Run main function
main "$@"
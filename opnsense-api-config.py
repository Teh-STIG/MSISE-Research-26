#!/usr/bin/env python3

################################################################################
# Proxmox Cybersecurity Lab Automation - OPNsense API Configuration
# 
# This script uses the OPNsense API Client to automate firewall configuration
# after OPNsense VM boots. Replaces manual web console configuration steps.
#
# GitHub: https://github.com/O-X-L/opnsense-api-client
# PyPI: pip install oxl-opnsense-client
#
# Author: Generated from lab documentation
# Version: 1.0
# Last Updated: 2025-12-01
################################################################################

import sys
import time
import argparse
import logging
from typing import Optional, Dict, List, Tuple
from pathlib import Path

# Import OPNsense API Client
try:
    from oxl_opnsense_client import Client
except ImportError:
    print("ERROR: oxl-opnsense-client not installed")
    print("Install with: pip install oxl-opnsense-client")
    sys.exit(1)

################################################################################
# CONFIGURATION
################################################################################

# OPNsense Connection Settings
OPNSENSE_HOST = "10.0.0.1"
OPNSENSE_PORT = 443
OPNSENSE_USERNAME = "root"
OPNSENSE_PASSWORD = "opnsense"  # CHANGE THIS AFTER FIRST LOGIN!

# API Credentials File (downloaded from OPNsense web UI)
# System > Administration > API > Generate Token
# Save as /root/.opnsense_api_credentials.txt
API_CREDENTIALS_FILE = Path.home() / ".opnsense_api_credentials.txt"

# Lab Network Configuration
LAN_IP = "10.0.0.1"
LAN_NETMASK = "24"
LAN_DHCP_START = "10.0.0.11"
LAN_DHCP_END = "10.0.0.244"

SEC_EGRESS_IP = "10.6.6.1"
SEC_EGRESS_NETMASK = "24"
SEC_EGRESS_DHCP_START = "10.6.6.11"
SEC_EGRESS_DHCP_END = "10.6.6.244"

SEC_ISOLATED_IP = "10.9.9.1"
SEC_ISOLATED_NETMASK = "24"
SEC_ISOLATED_DHCP_START = "10.9.9.11"
SEC_ISOLATED_DHCP_END = "10.9.9.244"

# Home Network for WAN Access
HOME_NETWORK = "172.16.1.0/24"

# Retry Settings
MAX_RETRIES = 5
RETRY_DELAY = 5

################################################################################
# LOGGING SETUP
################################################################################

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/root/opnsense_config.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

################################################################################
# HELPER FUNCTIONS
################################################################################

def log_info(message: str):
    """Log info message"""
    logger.info(f"[✓] {message}")

def log_warn(message: str):
    """Log warning message"""
    logger.warning(f"[⚠] {message}")

def log_error(message: str):
    """Log error message"""
    logger.error(f"[✗] {message}")

def log_section(title: str):
    """Log section header"""
    logger.info(f"\n{'='*70}")
    logger.info(f"  {title}")
    logger.info(f"{'='*70}\n")

def wait_for_opnsense(client: Client, max_retries: int = MAX_RETRIES) -> bool:
    """
    Wait for OPNsense to be reachable and responsive
    
    Args:
        client: OPNsense API client
        max_retries: Maximum retry attempts
    
    Returns:
        True if OPNsense is reachable, False otherwise
    """
    for attempt in range(1, max_retries + 1):
        try:
            if client.test():
                log_info("OPNsense is reachable and responsive")
                return True
        except Exception as e:
            log_warn(f"Attempt {attempt}/{max_retries}: OPNsense not ready - {str(e)}")
            if attempt < max_retries:
                log_info(f"Waiting {RETRY_DELAY} seconds before retry...")
                time.sleep(RETRY_DELAY)
    
    return False

def create_api_client(
    host: str,
    port: int = 443,
    username: str = None,
    password: str = None,
    credentials_file: Path = None,
    verify_ssl: bool = False
) -> Optional[Client]:
    """
    Create OPNsense API client with credentials
    
    Args:
        host: OPNsense host IP/hostname
        port: OPNsense API port (default 443)
        username: API username (if using basic auth)
        password: API password (if using basic auth)
        credentials_file: Path to credentials file
        verify_ssl: Verify SSL certificate
    
    Returns:
        Configured Client instance or None on error
    """
    try:
        if credentials_file and credentials_file.exists():
            log_info(f"Using credentials from {credentials_file}")
            client = Client(
                firewall=host,
                port=port,
                credential_file=str(credentials_file),
                ssl_verify=verify_ssl
            )
        elif username and password:
            log_warn("Using username/password (not recommended for production)")
            log_warn("Generate API token instead: System > Administration > API")
            # Note: oxl-opnsense-client requires credential_file format
            # For basic auth, create credentials file first
            client = Client(
                firewall=host,
                port=port,
                credential_file=str(credentials_file),
                ssl_verify=verify_ssl
            )
        else:
            log_error("No credentials provided")
            return None
        
        return client
    except Exception as e:
        log_error(f"Failed to create API client: {str(e)}")
        return None

################################################################################
# VLAN CONFIGURATION
################################################################################

def configure_vlans(client: Client) -> bool:
    """
    Configure VLANs on OPNsense
    
    Args:
        client: OPNsense API client
    
    Returns:
        True if successful, False otherwise
    """
    log_section("Configuring VLANs")
    
    try:
        # VLAN 666 (SEC_EGRESS)
        log_info("Creating VLAN 666 (SEC_EGRESS)...")
        result = client.run_module('interfaces_vlan_general', params={
            'vlan': {
                'vlanid': '666',
                'tag': 'SEC_EGRESS',
                'priority': '',
                'description': 'Security Egress Network'
            }
        })
        if result['error']:
            log_error(f"Failed to create VLAN 666: {result['error']}")
            return False
        log_info("VLAN 666 created successfully")
        
        # VLAN 999 (SEC_ISOLATED)
        log_info("Creating VLAN 999 (SEC_ISOLATED)...")
        result = client.run_module('interfaces_vlan_general', params={
            'vlan': {
                'vlanid': '999',
                'tag': 'SEC_ISOLATED',
                'priority': '',
                'description': 'Security Isolated Network'
            }
        })
        if result['error']:
            log_error(f"Failed to create VLAN 999: {result['error']}")
            return False
        log_info("VLAN 999 created successfully")
        
        return True
    
    except Exception as e:
        log_error(f"VLAN configuration failed: {str(e)}")
        return False

################################################################################
# INTERFACE CONFIGURATION
################################################################################

def configure_interfaces(client: Client) -> bool:
    """
    Configure network interfaces (LAN, OPT1, OPT2)
    
    Args:
        client: OPNsense API client
    
    Returns:
        True if successful, False otherwise
    """
    log_section("Configuring Network Interfaces")
    
    try:
        # Configure LAN Interface (em1)
        log_info("Configuring LAN interface (em1)...")
        result = client.run_module('interfaces_lan_settings', params={
            'lan': {
                'ipaddr': LAN_IP,
                'subnet': LAN_NETMASK,
                'track6': 'interface',
                'ipaddrv6': '',
                'subnetv6': '64'
            }
        })
        if result['error']:
            log_error(f"Failed to configure LAN: {result['error']}")
            return False
        log_info(f"LAN configured: {LAN_IP}/{LAN_NETMASK}")
        
        # Configure OPT1 Interface (SEC_EGRESS - VLAN 666)
        log_info("Configuring OPT1 interface (SEC_EGRESS)...")
        result = client.run_module('interfaces_opt1_settings', params={
            'opt1': {
                'enable': '1',
                'ipaddr': SEC_EGRESS_IP,
                'subnet': SEC_EGRESS_NETMASK,
                'track6': 'interface',
                'ipaddrv6': '',
                'subnetv6': '64'
            }
        })
        if result['error']:
            log_error(f"Failed to configure OPT1: {result['error']}")
            return False
        log_info(f"OPT1 (SEC_EGRESS) configured: {SEC_EGRESS_IP}/{SEC_EGRESS_NETMASK}")
        
        # Configure OPT2 Interface (SEC_ISOLATED - VLAN 999)
        log_info("Configuring OPT2 interface (SEC_ISOLATED)...")
        result = client.run_module('interfaces_opt2_settings', params={
            'opt2': {
                'enable': '1',
                'ipaddr': SEC_ISOLATED_IP,
                'subnet': SEC_ISOLATED_NETMASK,
                'track6': 'interface',
                'ipaddrv6': '',
                'subnetv6': '64'
            }
        })
        if result['error']:
            log_error(f"Failed to configure OPT2: {result['error']}")
            return False
        log_info(f"OPT2 (SEC_ISOLATED) configured: {SEC_ISOLATED_IP}/{SEC_ISOLATED_NETMASK}")
        
        return True
    
    except Exception as e:
        log_error(f"Interface configuration failed: {str(e)}")
        return False

################################################################################
# DHCP SERVER CONFIGURATION
################################################################################

def configure_dhcp(client: Client) -> bool:
    """
    Configure DHCP servers for all interfaces
    
    Args:
        client: OPNsense API client
    
    Returns:
        True if successful, False otherwise
    """
    log_section("Configuring DHCP Servers")
    
    try:
        # DHCP for LAN
        log_info(f"Configuring DHCP for LAN ({LAN_DHCP_START} - {LAN_DHCP_END})...")
        result = client.run_module('dhcp_lan', params={
            'dhcp': {
                'enable': '1',
                'range': {
                    'from': LAN_DHCP_START,
                    'to': LAN_DHCP_END
                }
            }
        })
        if result['error']:
            log_error(f"Failed to configure LAN DHCP: {result['error']}")
        else:
            log_info("LAN DHCP configured")
        
        # DHCP for OPT1 (SEC_EGRESS)
        log_info(f"Configuring DHCP for OPT1 ({SEC_EGRESS_DHCP_START} - {SEC_EGRESS_DHCP_END})...")
        result = client.run_module('dhcp_opt1', params={
            'dhcp': {
                'enable': '1',
                'range': {
                    'from': SEC_EGRESS_DHCP_START,
                    'to': SEC_EGRESS_DHCP_END
                }
            }
        })
        if result['error']:
            log_error(f"Failed to configure OPT1 DHCP: {result['error']}")
        else:
            log_info("OPT1 (SEC_EGRESS) DHCP configured")
        
        # DHCP for OPT2 (SEC_ISOLATED)
        log_info(f"Configuring DHCP for OPT2 ({SEC_ISOLATED_DHCP_START} - {SEC_ISOLATED_DHCP_END})...")
        result = client.run_module('dhcp_opt2', params={
            'dhcp': {
                'enable': '1',
                'range': {
                    'from': SEC_ISOLATED_DHCP_START,
                    'to': SEC_ISOLATED_DHCP_END
                }
            }
        })
        if result['error']:
            log_error(f"Failed to configure OPT2 DHCP: {result['error']}")
        else:
            log_info("OPT2 (SEC_ISOLATED) DHCP configured")
        
        return True
    
    except Exception as e:
        log_error(f"DHCP configuration failed: {str(e)}")
        return False

################################################################################
# FIREWALL ALIASES
################################################################################

def configure_aliases(client: Client) -> bool:
    """
    Configure firewall aliases (RFC1918, Kali, etc.)
    
    Args:
        client: OPNsense API client
    
    Returns:
        True if successful, False otherwise
    """
    log_section("Configuring Firewall Aliases")
    
    try:
        # RFC1918 Alias (private networks)
        log_info("Creating RFC1918 alias...")
        result = client.run_module('firewall_alias_util_add', params={
            'alias': {
                'enabled': '1',
                'name': 'RFC1918',
                'description': 'Private IPv4 ranges (RFC 1918)',
                'type': 'network',
                'content': '10.0.0.0/8 172.16.0.0/12 192.168.0.0/16'
            }
        })
        if result['error']:
            log_warn(f"RFC1918 alias may already exist: {result['error']}")
        else:
            log_info("RFC1918 alias created")
        
        # Kali Alias
        log_info("Creating Kali alias...")
        result = client.run_module('firewall_alias_util_add', params={
            'alias': {
                'enabled': '1',
                'name': 'Kali',
                'description': 'Kali Linux penetration testing VM',
                'type': 'host',
                'content': '10.0.0.2'
            }
        })
        if result['error']:
            log_warn(f"Kali alias may already exist: {result['error']}")
        else:
            log_info("Kali alias created")
        
        # Home Network Alias
        log_info("Creating Home Network alias...")
        result = client.run_module('firewall_alias_util_add', params={
            'alias': {
                'enabled': '1',
                'name': 'HomeNetwork',
                'description': 'Home network for lab access',
                'type': 'network',
                'content': HOME_NETWORK
            }
        })
        if result['error']:
            log_warn(f"HomeNetwork alias may already exist: {result['error']}")
        else:
            log_info("HomeNetwork alias created")
        
        return True
    
    except Exception as e:
        log_error(f"Alias configuration failed: {str(e)}")
        return False

################################################################################
# FIREWALL RULES
################################################################################

def configure_firewall_rules(client: Client) -> bool:
    """
    Configure firewall rules for lab network segmentation
    
    Args:
        client: OPNsense API client
    
    Returns:
        True if successful, False otherwise
    """
    log_section("Configuring Firewall Rules")
    
    try:
        # WAN Rule: Allow home network to internal LAN
        log_info("Creating WAN rule: Allow home network to LAN...")
        result = client.run_module('firewall_filter_add', params={
            'rule': {
                'enabled': '1',
                'interface': 'wan',
                'action': 'pass',
                'protocol': 'any',
                'source': 'HomeNetwork',
                'destination': 'LAN',
                'description': 'Allow home network to internal lab'
            }
        })
        if result['error']:
            log_warn(f"WAN rule creation issue: {result['error']}")
        else:
            log_info("WAN rule created")
        
        # SEC_EGRESS Rule: Allow to gateway
        log_info("Creating SEC_EGRESS rule: Allow to gateway...")
        result = client.run_module('firewall_filter_add', params={
            'rule': {
                'enabled': '1',
                'interface': 'opt1',  # SEC_EGRESS
                'action': 'pass',
                'protocol': 'any',
                'source': '10.6.6.0/24',
                'destination': '10.0.0.1',
                'description': 'SEC_EGRESS to gateway'
            }
        })
        if result['error']:
            log_warn(f"SEC_EGRESS gateway rule issue: {result['error']}")
        else:
            log_info("SEC_EGRESS to gateway rule created")
        
        # SEC_EGRESS Rule: Allow to Kali
        log_info("Creating SEC_EGRESS rule: Allow to Kali...")
        result = client.run_module('firewall_filter_add', params={
            'rule': {
                'enabled': '1',
                'interface': 'opt1',  # SEC_EGRESS
                'action': 'pass',
                'protocol': 'any',
                'source': '10.6.6.0/24',
                'destination': 'Kali',
                'description': 'SEC_EGRESS to Kali'
            }
        })
        if result['error']:
            log_warn(f"SEC_EGRESS Kali rule issue: {result['error']}")
        else:
            log_info("SEC_EGRESS to Kali rule created")
        
        # SEC_EGRESS Rule: Allow to internet (non-RFC1918)
        log_info("Creating SEC_EGRESS rule: Allow internet...")
        result = client.run_module('firewall_filter_add', params={
            'rule': {
                'enabled': '1',
                'interface': 'opt1',  # SEC_EGRESS
                'action': 'pass',
                'protocol': 'any',
                'source': '10.6.6.0/24',
                'destination': '!RFC1918',
                'description': 'SEC_EGRESS to internet'
            }
        })
        if result['error']:
            log_warn(f"SEC_EGRESS internet rule issue: {result['error']}")
        else:
            log_info("SEC_EGRESS internet rule created")
        
        # SEC_ISOLATED Rule: Allow DNS
        log_info("Creating SEC_ISOLATED rule: Allow DNS...")
        result = client.run_module('firewall_filter_add', params={
            'rule': {
                'enabled': '1',
                'interface': 'opt2',  # SEC_ISOLATED
                'action': 'pass',
                'protocol': 'tcp/udp',
                'source': '10.9.9.0/24',
                'destination': '10.0.0.1',
                'destination_port': '53',
                'description': 'SEC_ISOLATED DNS'
            }
        })
        if result['error']:
            log_warn(f"SEC_ISOLATED DNS rule issue: {result['error']}")
        else:
            log_info("SEC_ISOLATED DNS rule created")
        
        # SEC_ISOLATED Rule: Allow to Kali only
        log_info("Creating SEC_ISOLATED rule: Allow to Kali only...")
        result = client.run_module('firewall_filter_add', params={
            'rule': {
                'enabled': '1',
                'interface': 'opt2',  # SEC_ISOLATED
                'action': 'pass',
                'protocol': 'any',
                'source': '10.9.9.0/24',
                'destination': 'Kali',
                'description': 'SEC_ISOLATED to Kali'
            }
        })
        if result['error']:
            log_warn(f"SEC_ISOLATED Kali rule issue: {result['error']}")
        else:
            log_info("SEC_ISOLATED to Kali rule created")
        
        return True
    
    except Exception as e:
        log_error(f"Firewall rule configuration failed: {str(e)}")
        return False

################################################################################
# DNS CONFIGURATION
################################################################################

def configure_dns(client: Client) -> bool:
    """
    Configure DNS forwarder (Unbound)
    
    Args:
        client: OPNsense API client
    
    Returns:
        True if successful, False otherwise
    """
    log_section("Configuring DNS Forwarder (Unbound)")
    
    try:
        log_info("Enabling Unbound DNS forwarder...")
        result = client.run_module('unbound_settings', params={
            'unbound': {
                'enabled': '1',
                'port': '53',
                'logqueries': '1'
            }
        })
        if result['error']:
            log_warn(f"DNS configuration issue: {result['error']}")
        else:
            log_info("DNS forwarder configured")
        
        return True
    
    except Exception as e:
        log_error(f"DNS configuration failed: {str(e)}")
        return False

################################################################################
# SYSTEM CONFIGURATION
################################################################################

def configure_system(client: Client, new_password: Optional[str] = None) -> bool:
    """
    Configure system settings
    
    Args:
        client: OPNsense API client
        new_password: Optional new root password
    
    Returns:
        True if successful, False otherwise
    """
    log_section("Configuring System Settings")
    
    try:
        log_info("Enabling SSH...")
        result = client.run_module('system_settings_administration', params={
            'administration': {
                'enablessh': '1',
                'permitrootlogin': '1'
            }
        })
        if result['error']:
            log_warn(f"SSH configuration issue: {result['error']}")
        else:
            log_info("SSH enabled")
        
        if new_password:
            log_warn(f"Password change requires manual intervention or direct API call")
            log_info("Change password via: System > Administration > Change Password")
        
        return True
    
    except Exception as e:
        log_error(f"System configuration failed: {str(e)}")
        return False

################################################################################
# SERVICE RESTART
################################################################################

def restart_services(client: Client) -> bool:
    """
    Restart required services to apply configuration
    
    Args:
        client: OPNsense API client
    
    Returns:
        True if successful, False otherwise
    """
    log_section("Restarting Services")
    
    try:
        log_info("Restarting firewall...")
        result = client.run_module('firewall_filter_reload', params={})
        if result['error']:
            log_warn(f"Firewall restart issue: {result['error']}")
        else:
            log_info("Firewall restarted")
        
        log_info("Restarting DHCP server...")
        result = client.run_module('dhcp_general_restart', params={})
        if result['error']:
            log_warn(f"DHCP restart issue: {result['error']}")
        else:
            log_info("DHCP restarted")
        
        log_info("Restarting DNS forwarder...")
        result = client.run_module('unbound_service_restart', params={})
        if result['error']:
            log_warn(f"DNS restart issue: {result['error']}")
        else:
            log_info("DNS restarted")
        
        return True
    
    except Exception as e:
        log_error(f"Service restart failed: {str(e)}")
        return False

################################################################################
# MAIN EXECUTION
################################################################################

def main():
    """Main execution function"""
    
    parser = argparse.ArgumentParser(
        description='OPNsense Firewall Configuration Automation'
    )
    parser.add_argument(
        '--host',
        default=OPNSENSE_HOST,
        help=f'OPNsense host IP (default: {OPNSENSE_HOST})'
    )
    parser.add_argument(
        '--port',
        type=int,
        default=OPNSENSE_PORT,
        help=f'OPNsense API port (default: {OPNSENSE_PORT})'
    )
    parser.add_argument(
        '--credentials-file',
        type=Path,
        default=API_CREDENTIALS_FILE,
        help=f'Path to API credentials file (default: {API_CREDENTIALS_FILE})'
    )
    parser.add_argument(
        '--no-ssl-verify',
        action='store_true',
        help='Disable SSL verification (lab only!)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Show what would be done without making changes'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    log_section("OPNsense Firewall Automation - API Configuration")
    log_info(f"Target: {args.host}:{args.port}")
    log_info(f"Credentials file: {args.credentials_file}")
    
    # Check if credentials file exists
    if not args.credentials_file.exists():
        log_error(f"Credentials file not found: {args.credentials_file}")
        log_info("Generate API credentials:")
        log_info("1. Access OPNsense web console: https://10.0.0.1:443")
        log_info("2. Go to: System > Administration > API")
        log_info("3. Click: Generate new key")
        log_info("4. Save the credentials file to the path above")
        return False
    
    # Create API client
    log_info("Connecting to OPNsense...")
    client = create_api_client(
        host=args.host,
        port=args.port,
        credentials_file=args.credentials_file,
        verify_ssl=not args.no_ssl_verify
    )
    
    if not client:
        log_error("Failed to create API client")
        return False
    
    # Wait for OPNsense to be responsive
    log_info("Waiting for OPNsense to be responsive...")
    if not wait_for_opnsense(client):
        log_error("OPNsense is not responding. Verify:")
        log_info("1. OPNsense VM is booted and running")
        log_info("2. Console configuration completed (em0 DHCP, em1 10.0.0.1/24)")
        log_info("3. API credentials are correct")
        log_info("4. Network connectivity is working")
        return False
    
    if args.dry_run:
        log_warn("DRY RUN MODE - No changes will be made")
    
    # Execute configuration steps
    steps = [
        ("VLANs", lambda: configure_vlans(client)),
        ("Interfaces", lambda: configure_interfaces(client)),
        ("DHCP", lambda: configure_dhcp(client)),
        ("Aliases", lambda: configure_aliases(client)),
        ("Firewall Rules", lambda: configure_firewall_rules(client)),
        ("DNS", lambda: configure_dns(client)),
        ("System", lambda: configure_system(client)),
        ("Services", lambda: restart_services(client)),
    ]
    
    failed_steps = []
    for step_name, step_func in steps:
        try:
            if not step_func():
                failed_steps.append(step_name)
                log_warn(f"{step_name} configuration had issues")
        except Exception as e:
            failed_steps.append(step_name)
            log_error(f"{step_name} failed with exception: {str(e)}")
    
    # Summary
    log_section("Configuration Summary")
    
    if failed_steps:
        log_error(f"Configuration completed with errors in: {', '.join(failed_steps)}")
        log_info("Review /root/opnsense_config.log for details")
        return False
    else:
        log_info("✅ All configurations applied successfully!")
        log_info("\nNext steps:")
        log_info("1. Verify firewall rules in OPNsense web console")
        log_info("2. Test DHCP on LAN, OPT1, OPT2 subnets")
        log_info("3. Boot Kali VM and verify IP assignment")
        log_info("4. Boot Wazuh containers and verify connectivity")
        log_info("5. Test network isolation between subnets")
        log_info("\nCredentials:")
        log_info(f"SSH: ssh root@{args.host}")
        log_info(f"Web UI: https://{args.host}:443")
        log_info("Logs: /root/opnsense_config.log")
        return True

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)

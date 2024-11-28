#!/bin/bash

# Required packages for integration
REQUIRED_PACKAGES=(
  realmd
  sssd
  sssd-tools
  libnss-sss
  libpam-sss
  adcli
  samba-common
  samba-common-bin
  oddjob
  oddjob-mkhomedir
  packagekit
)

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root (use sudo)."
  exit 1
fi

# Function to configure DNS in /etc/resolv.conf
configure_dns() {
  echo "Configuring DNS..."

  # Prompt for DNS server
  read -p "Enter the DNS server IP (e.g., 192.168.1.1): " dns_ip

  # Prompt for domain (optional)
  read -p "Enter the domain name (optional, e.g., example.com): " domain_name

  # Prompt for search domain (optional)
  read -p "Enter the search domain (optional, e.g., example.com): " search_domain

  # Validate DNS IP input
  if [[ -z "$dns_ip" ]]; then
    echo "No DNS IP provided. Skipping DNS configuration."
    return
  fi

  # Write DNS configuration to /etc/resolv.conf
  {
    echo "nameserver $dns_ip"
    [[ -n "$domain_name" ]] && echo "domain $domain_name"
    [[ -n "$search_domain" ]] && echo "search $search_domain"
  } > /etc/resolv.conf

  echo "/etc/resolv.conf configured with the following:"
  cat /etc/resolv.conf
}

# Function to configure static IP in /etc/network/interfaces
configure_ip() {
  echo "Configuring static IP address..."
  read -p "Enter the network interface name (e.g., eth0): " interface
  read -p "Enter the static IP address (e.g., 192.168.1.100): " static_ip
  read -p "Enter the subnet mask (e.g., 255.255.255.0): " netmask
  read -p "Enter the gateway IP (e.g., 192.168.1.1): " gateway

  if [[ -z "$interface" || -z "$static_ip" || -z "$netmask" || -z "$gateway" ]]; then
    echo "Invalid network configuration. Skipping IP configuration."
    return
  fi

  cat > /etc/network/interfaces <<EOF
allow-hotplug $interface
iface $interface inet static
    address $static_ip
    netmask $netmask
    gateway $gateway
EOF

  echo "Static IP configuration written to /etc/network/interfaces."
  echo "Restarting networking service..."
  systemctl restart networking || echo "Failed to restart networking. Please check the configuration."
}

# Function to check and install missing packages
check_and_install_packages() {
  echo "Checking for required packages..."

  # Ensure the package lists are updated
  echo "Updating package repositories..."
  apt update -y || { echo "Failed to update package repositories. Exiting."; exit 1; }

  MISSING_PACKAGES=()
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -qw "$pkg"; then
      MISSING_PACKAGES+=("$pkg")
    fi
  done

  if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
    echo "All required packages are already installed."
  else
    echo "The following packages are missing and will be installed: ${MISSING_PACKAGES[*]}"
    apt install -y "${MISSING_PACKAGES[@]}" || {
      echo "Failed to install some packages. Please check your package manager or dependencies.";
      exit 1;
    }
    echo "All required packages have been installed."
  fi
}


# Function to join the Active Directory domain
configure_ad_integration() {
  echo "Enter the full Active Directory domain name (e.g., example.com): "
  read -r domain_name

  echo "Checking DNS for the domain..."
  if ! realm discover "$domain_name"; then
    echo "The domain $domain_name was not found. Please check DNS or the domain name."
    exit 1
  fi

  echo "Enter the username of a domain admin account (with rights to add machines): "
  read -r admin_user

  echo "Joining the domain..."
  realm join --user="$admin_user" "$domain_name" || {
    echo "Failed to join the domain $domain_name. Please verify your credentials.";
    exit 1;
  }

  echo "Successfully joined the domain!"
}

# Function to configure SSSD
configure_sssd() {
  echo "Configuring SSSD..."
  cat > /etc/sssd/sssd.conf <<EOF
[sssd]
domains = $domain_name
config_file_version = 2
services = nss, pam

[domain/$domain_name]
ad_domain = $domain_name
krb5_realm = ${domain_name^^}
realmd_tags = manages-system joined-with-samba
cache_credentials = true
id_provider = ad
auth_provider = ad
access_provider = ad
override_homedir = /home/%d/%u
default_shell = /bin/bash
ldap_id_mapping = true
EOF

  chmod 600 /etc/sssd/sssd.conf

  echo "Restarting SSSD..."
  systemctl restart sssd || {
    echo "Failed to restart SSSD. Please check the configuration.";
    exit 1;
  }

  echo "SSSD configuration complete."
}

# Function to enable and start necessary services
activate_services() {
  echo "Activating and starting necessary services..."

  # Enable and start SSSD
  systemctl enable sssd && systemctl start sssd || {
    echo "Failed to start SSSD service. Please check logs.";
    exit 1;
  }

  # Ensure that realmd is operational
  systemctl enable realmd && systemctl start realmd || {
    echo "Failed to start realmd service. Please check logs.";
    exit 1;
  }

  # Restart services to apply changes
  systemctl restart sssd
  systemctl restart realmd

  echo "All necessary services have been activated and started."
}


# Interactive menu
echo "==============================="
echo " Linux Active Directory Setup "
echo "==============================="

echo "This script will:"
echo "1. Configure DNS settings"
echo "2. Configure a static IP address"
echo "3. Check for and install missing packages"
echo "4. Configure Active Directory integration"
echo "5. Set up SSSD for NSS and PAM services"
echo ""

read -p "Do you want to proceed? (yes/no): " confirmation
if [[ "$confirmation" =~ ^(yes|y)$ ]]; then
  configure_dns
  configure_ip
  check_and_install_packages
  configure_ad_integration
  configure_sssd
  echo "Active Directory integration completed successfully!"
else
  echo "Operation cancelled. No changes were made."
fi

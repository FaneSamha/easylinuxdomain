# Linux AD Integration Script

This script simplifies the process of integrating a Linux machine into a Windows Active Directory (AD) domain. It installs required dependencies, configures authentication, and ensures proper setup of SSSD for NSS and PAM.

## Prerequisites

Before running the script, ensure the following:

- **Operating System:** Debian-based distributions (e.g., Ubuntu)
- **Privileges:** You must run the script as root (`sudo`).
- **Network Configuration:** DNS must be properly configured to resolve the AD domain.

## Features

- Installs necessary packages (`realmd`, `sssd`, `adcli`, etc.)
- Configure interfaces and resolv
- Configures domain join with `realm`
- Automatically sets up SSSD for authentication and home directory management
- Interactive and user-friendly

## How to Use

1. Clone the repository:
   ```bash
   git clone https://github.com/FaneSamha/easylinuxdomain.git
   cd easylinuxdomain && chmod +x script.sh
   ./script.sh
   ```

   Follow the script and enjoy :) 

#!/bin/bash

# Colors and styling
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Spinner function for visual feedback
spinner() {
    local pid=$1
    local msg="$2"
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    tput civis  # Hide cursor
    while kill -0 $pid 2>/dev/null; do
        for i in $(seq 0 9); do
            printf "\r${BLUE}${BOLD}[${spinstr:$i:1}]${NC} ${msg}"
            sleep 0.1
        done
    done
    wait $pid
    local exit_status=$?
    if [ $exit_status -eq 0 ]; then
        printf "\r${GREEN}${BOLD}[✓]${NC} ${msg}\n"
    else
        printf "\r${RED}${BOLD}[✗]${NC} ${msg}\n"
        exit $exit_status
    fi
    tput cnorm  # Show cursor
}

# Function to run command with spinner
run_with_spinner() {
    local msg="$1"
    shift
    ("$@") &
    spinner $! "$msg"
}

# Function to apply sysctl settings
apply_sysctl_settings() {
    run_with_spinner "Configuring system settings" bash -c '
        # Remove existing configuration if it exists
        rm -f /etc/sysctl.d/99.elysium.conf

        # Create new configuration
        cat > /etc/sysctl.d/99.elysium.conf << "EOF"
# Memory Management
vm.swappiness = 100
vm.vfs_cache_pressure = 50
vm.dirty_bytes = 268435456
vm.page-cluster = 0
vm.dirty_background_bytes = 67108864
vm.dirty_writeback_centisecs = 1500

# Kernel Settings
kernel.nmi_watchdog = 0
kernel.unprivileged_userns_clone = 1
kernel.printk = 3 3 3 3
kernel.kptr_restrict = 2
kernel.kexec_load_disabled = 1
kernel.split_lock_mitigate=0

# Network Settings
net.ipv4.tcp_ecn = 1
net.core.netdev_max_backlog = 4096
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_rfc1337 = 1

# File System Settings
fs.file-max = 2097152
fs.xfs.xfssyncd_centisecs = 10000
EOF

        # Apply settings
        sysctl --system &>/dev/null
    '
}

# Function to verify settings
verify_settings() {
    run_with_spinner "Verifying system settings" bash -c "
        errors=0
        
        # Test a few key settings
        if [ \"\$(sysctl -n vm.swappiness)\" != \"100\" ]; then
            echo -e \"${RED}${BOLD}[✗]${NC} vm.swappiness not set correctly\"
            errors=\$((errors+1))
        fi
        
        if [ \"\$(sysctl -n vm.vfs_cache_pressure)\" != \"50\" ]; then
            echo -e \"${RED}${BOLD}[✗]${NC} vm.vfs_cache_pressure not set correctly\"
            errors=\$((errors+1))
        fi
        
        if [ \"\$(sysctl -n fs.file-max)\" != \"2097152\" ]; then
            echo -e \"${RED}${BOLD}[✗]${NC} fs.file-max not set correctly\"
            errors=\$((errors+1))
        fi
        
        if [ \"\$errors\" -gt 0 ]; then
            echo -e \"${RED}${BOLD}[✗]${NC} Some settings were not applied correctly\"
            exit 1
        fi
    "
}

# Function to check current configuration status
check_current_status() {
    # Check if config file exists
    if [ ! -f "/etc/sysctl.d/99.elysium.conf" ]; then
        return 1
    fi
    
    # Verify key settings
    if [ "$(sysctl -n vm.swappiness)" != "100" ] || \
       [ "$(sysctl -n vm.vfs_cache_pressure)" != "50" ] || \
       [ "$(sysctl -n fs.file-max)" != "2097152" ]; then
        return 1
    fi
    
    return 0
}

# Main script
clear
echo -e "${BLUE}${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}${BOLD}║      System Settings Optimization      ║${NC}"
echo -e "${BLUE}${BOLD}╚════════════════════════════════════════╝${NC}"
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}${BOLD}[✗]${NC} This script must be run as root"
    exit 1
fi

# Check current status and existing configurations
if check_current_status; then
    echo -e "${GREEN}${BOLD}[✓]${NC} Current system settings are properly optimized."
    echo -ne "${BLUE}${BOLD}[?]${NC} Would you like to reconfigure anyway? [y/N] "
    CONFIGS_EXIST=1
elif [ -f "/etc/sysctl.d/99.elysium.conf" ]; then
    echo -e "${YELLOW}${BOLD}[!]${NC} Existing system settings found but may not be optimal."
    echo -ne "${BLUE}${BOLD}[?]${NC} Would you like to reconfigure? [y/N] "
    CONFIGS_EXIST=1
else
    echo -e "${RED}${BOLD}[✗]${NC} No system optimizations found."
    echo -ne "${BLUE}${BOLD}[?]${NC} Would you like to configure system optimizations? [Y/n] "
    CONFIGS_EXIST=0
fi

read -n 1 -r REPLY
echo

if [ $CONFIGS_EXIST -eq 1 ]; then
    # For existing configs, require explicit yes
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}${BOLD}[!]${NC} Setup cancelled."
        exit 0
    fi
    # Clean up old configuration before proceeding
    run_with_spinner "Removing existing configuration" bash -c 'rm -f /etc/sysctl.d/99.elysium.conf'
else
    # For new installation, proceed unless explicit no
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ ! -z $REPLY ]]; then
        echo -e "${YELLOW}${BOLD}[!]${NC} Setup cancelled."
        exit 0
    fi
fi

echo -e "\n${BLUE}${BOLD}[i]${NC} Applying system optimizations..."

# Apply settings
apply_sysctl_settings

# Verify settings
verify_settings

echo -e "\n${GREEN}${BOLD}[✓]${NC} System settings have been optimized!"
echo -e "${BLUE}${BOLD}[i]${NC} Changes will persist across reboots"
echo -e "${YELLOW}${BOLD}[!]${NC} You may need to reboot for all changes to take effect" 

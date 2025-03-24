#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/tteck/Proxmox/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
  clear
  cat <<"EOF"
    _   __          __       __                __   __  __      __
   / | / /__  _  __/ /______/ /___  __  ______/ /  / / / /_  __/ /_
  /  |/ / _ \| |/_/ __/ ___/ / __ \/ / / / __  /  / /_/ / / / / __ \
 / /|  /  __/>  </ /_/ /__/ / /_/ / /_/ / /_/ /  / __  / /_/ / /_/ /
/_/ |_/\___/_/|_|\__/\___/_/\____/\__,_/\__,_/  /_/ /_/\__,_/_.___/
Alpine
EOF
}
header_info
echo -e "Loading..."
APP="Alpine-Nextcloud"
var_disk="2"
var_cpu="2"
var_ram="1024"
var_os="alpine"
var_version="3.19"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
  if [[ ! -d /usr/share/webapps/nextcloud ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi
  if ! apk -e info newt >/dev/null 2>&1; then
    apk add -q newt
  fi
  while true; do
    CHOICE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "SUPPORT" --radiolist --cancel-button Exit-Script "Spacebar = Select"  11 58 3 \
      "1" "Nextcloud Login Credentials" ON \
      "2" "Renew Self-signed Certificate" OFF \
      3>&1 1>&2 2>&3)      
    exit_status=$?
    if [ $exit_status == 1 ]; then
      clear
      exit-script
    fi
    header_info
    case $CHOICE in
    1)
      cat nextcloud.creds
      exit
      ;;
    2)
      openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout /etc/ssl/private/nextcloud-selfsigned.key -out /etc/ssl/certs/nextcloud-selfsigned.crt -subj "/C=US/O=Nextcloud/OU=Domain Control Validated/CN=nextcloud.local" > /dev/null 2>&1
      rc-service nginx restart
      exit
      ;;
    esac
  done
}

start
build_container
description

# Wait for container to fully initialize
msg_info "Waiting for container to initialize..."
sleep 10

# Execute the Nextcloud installation script inside the container
msg_info "Installing Nextcloud in the container..."

# First make sure bash is installed in the container
pct exec $CTID -- apk add bash

# Create a wrapper script to handle FUNCTIONS_FILE_PATH
cat > /tmp/nextcloud-wrapper.sh << 'EOF'
#!/bin/bash

# Create functions script with required functions
cat > /tmp/functions.sh << 'INNER'
# Basic functions needed by the installer
function color() { export NEWT_COLORS='root=,black'; }
function verb_ip6() { echo "IPv6 Configured"; }
function catch_errors() { set -e; }
function setting_up_container() { echo "Setting up container..."; }
function network_check() { echo "Network check passed..."; }
function update_os() { apk update > /dev/null 2>&1; }
function msg_info() { echo -e "\e[1;32m$1\e[0m"; }
function msg_ok() { echo -e "\e[1;32m$1\e[0m"; }
export STD='> /dev/null 2>&1'
INNER

# Set the FUNCTIONS_FILE_PATH variable
export FUNCTIONS_FILE_PATH="/tmp/functions.sh"

# Download and run the script
wget -q https://raw.githubusercontent.com/Tater-T/ProxmoxNextcloudScript/main/ct/alpine-nextcloud.sh -O /tmp/nextcloud-install.sh
chmod +x /tmp/nextcloud-install.sh
bash /tmp/nextcloud-install.sh
EOF

# Copy wrapper script to container
pct push $CTID /tmp/nextcloud-wrapper.sh /tmp/nextcloud-wrapper.sh
pct exec $CTID -- chmod +x /tmp/nextcloud-wrapper.sh
pct exec $CTID -- bash /tmp/nextcloud-wrapper.sh

msg_ok "Nextcloud installation completed!"

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}https://${IP}${CL} \n" 
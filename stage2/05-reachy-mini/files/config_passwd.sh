#!/bin/bash

# Usage: ./config_passwd.sh

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Extract serial number from dfu-util -l
SERIAL=$(dfu-util -l 2>/dev/null | grep -m1 'serial="' | sed 's/.*serial="\([0-9]*\)".*/\1/')
if [ -z "$SERIAL" ]; then
    echo "Could not find serial number from dfu-util."
    exit 1
fi

# Get last seven digits as pin code
PIN_CODE=${SERIAL: -7}
if [ -z "$PIN_CODE" ]; then
    echo "Could not extract pin code from serial number."
    exit 1
fi

# Change password for pollen user
if echo "pollen:$PIN_CODE" | chpasswd; then
    echo "Password for user 'pollen' changed successfully. New pin: $PIN_CODE"
    touch /home/pollen/.CONFIGURED
else
    echo "Failed to change password for user 'pollen'."
    exit 1
fi

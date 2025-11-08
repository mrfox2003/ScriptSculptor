#!/bin/bash

# Check if swap is already enabled
if swapon --show | grep -q '/swapfile'; then
    CURRENT_SWAP_SIZE=$(swapon --show --bytes | awk '/\/swapfile/ {print $3}')
    DESIRED_SIZE=$((32 * 1024 * 1024 * 1024)) # 32 GB in bytes

    if [ "$CURRENT_SWAP_SIZE" -lt "$DESIRED_SIZE" ]; then
        echo "Swap is enabled but less than 32GB. Recreating swap file..."

        # Turn off and remove current swap
        sudo swapoff /swapfile
        sudo rm -f /swapfile

        # Create new 32GB swap file
        sudo dd if=/dev/zero of=/swapfile bs=1G count=32 status=progress
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile

        # Ensure it's in /etc/fstab (replace any old entry)
        sudo sed -i '/\/swapfile/d' /etc/fstab
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

        # Adjust swappiness
        sudo sed -i '/vm.swappiness/d' /etc/sysctl.conf
        echo 'vm.swappiness=30' | sudo tee -a /etc/sysctl.conf
        sudo sysctl -p

        echo "Swap file resized to 32GB successfully."
    else
        echo "Swap is already 32GB or larger. No changes made."
    fi
else
    echo "No swap file found. Creating a 32GB swap file..."

    sudo dd if=/dev/zero of=/swapfile bs=1G count=32 status=progress
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo 'vm.swappiness=30' | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p

    echo "Swap file created and configured successfully."
fi

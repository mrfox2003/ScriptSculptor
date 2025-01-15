#!/bin/bash

# Check if swap is already enabled
if swapon --show; then
    echo "Swap is already enabled."
else
    echo "No swap file found. Creating a 32GB swap file..."

    # Create a 32 GB swap file
    sudo dd if=/dev/zero of=/swapfile bs=1G count=32

    # Set correct permissions
    sudo chmod 600 /swapfile

    # Format the file as swap
    sudo mkswap /swapfile

    # Enable the swap file
    sudo swapon /swapfile

    # Make swap permanent by adding to fstab
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

    # Set swappiness to 10 (optional)
    echo 'vm.swappiness=30' | sudo tee -a /etc/sysctl.conf

    # Apply changes
    sudo sysctl -p

    echo "Swap file created and configured successfully."
fi

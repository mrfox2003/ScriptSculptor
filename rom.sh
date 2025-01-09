#!/bin/bash
# set -e

# Check if the voltageos directory exists
if [ -d ""$HOME"/voltageos" ]; then
    # Directory exists, proceed with syncing
    echo "Directory 'voltageos' found. Proceeding with repo sync..."

    # Get the number of CPU cores (x) on the server
    x=$(nproc --all)
    echo "Detected $x cores. Using $x for the sync process."

    # Navigate to the voltageos directory
    cd "$HOME"/voltageos || { echo "Failed to change directory to 'voltageos'. Exiting..."; exit 1; }

    # Perform repo sync with force-sync option
    echo "Performing repo sync with force-sync..."
    repo sync --force-sync -j"$x" --no-clone-bundle --no-tags || { echo "Repo sync failed! Exiting..."; exit 1; }

    echo "VoltageOS source sync completed successfully!"

else
    # Directory does not exist, initialize the repo
    echo "Directory 'voltageos' not found. Creating directory and initializing VoltageOS repo..."

    # Create a directory for VoltageOS
    mkdir -p "$HOME"/voltageos  # -p ensures no error if the directory already exists

    # Navigate into the created directory
    cd "$HOME"/voltageos || { echo "Failed to change directory! Exiting..."; exit 1; }

    # Initialize VoltageOS source using repo
    echo "Initializing VoltageOS source..."
    repo init -u https://github.com/VoltageOS/manifest.git -b 14 --git-lfs || { echo "Repo initialization failed! Exiting..."; exit 1; }

    # Sync the source
    echo "Syncing VoltageOS source with repo..."
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags || { echo "Repo sync failed! Exiting..."; exit 1; }

    echo "VoltageOS source initialization and sync completed successfully!"
fi

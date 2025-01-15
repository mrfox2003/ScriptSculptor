#!/bin/bash

# Install ccache
echo "Installing ccache..."
sudo apt-get install -y ccache

# Set maximum cache size to 50GB
echo "Setting cache size to 50GB..."
ccache -M 50G

# Display current cache statistics
echo "Displaying cache statistics..."
ccache -s

# Clear the ccache cache
echo "Clearing ccache cache..."
ccache -F 0

echo "ccache setup and cache cleared."

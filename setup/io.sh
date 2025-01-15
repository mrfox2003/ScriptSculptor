#!/bin/bash
# Optimizing disk settings for maximum performance based on system specs

# Set read-ahead to 2 MB (increased for larger disk and more RAM)
echo "Setting read-ahead to 2 MB..."
echo 2048 | sudo tee /sys/block/vda/queue/read_ahead_kb

# Set I/O scheduler to deadline (optimized for performance)
echo "Setting I/O scheduler to deadline..."
echo deadline | sudo tee /sys/block/vda/queue/scheduler

# Set journal mode to writeback for /dev/vda1 (for performance)
echo "Changing journaling mode to writeback for /dev/vda1..."
sudo tune2fs -o journal_data_writeback /dev/vda1

# Confirm settings
echo "Verifying changes..."

# Check read-ahead value
echo "Current read-ahead value:"
cat /sys/block/vda/queue/read_ahead_kb

# Check I/O scheduler
echo "Current I/O scheduler:"
cat /sys/block/vda/queue/scheduler

# Check journaling mode for /dev/vda1
echo "Current journaling mode for /dev/vda1:"
sudo tune2fs -l /dev/vda1 | grep 'Default mount options'

echo "Disk optimization script completed."

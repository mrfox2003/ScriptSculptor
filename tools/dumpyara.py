import os
import subprocess

# Define colors for output (optional, for terminal color compatibility)
green = "\033[92m"
white = "\033[0m"

# Replace links accordingly
OEMZIP = "www.link.com"
DT = "https://github.com/narikootam-dev/device_xiaomi_sweet"
VT = "https://github.com/narikootam-dev/vendor_xiaomi_sweet"
DEVICENAME = "xiaomi/sweet"  # Enter device name accordingly

# Function to run shell commands and handle errors
def run_command(command, shell=False):
    try:
        subprocess.run(command, shell=shell, check=True)
    except subprocess.CalledProcessError as e:
        print(f"{white}Error: {e}")

# Step 1: Initialize script
print(f"{green}<< Initializing script >>{white}\n")

# Step 2: Clone Dumpyara repository
print(f"{green}<< Cloning Dumpyara >>{white}\n")
run_command(["git", "clone", "https://github.com/AndroidDumps/dumpyara", "dumpyara"])

# Step 3: Setup Dumpyara
os.chdir("dumpyara")
print(f"{green}<< Setting up >>{white}\n")
run_command(["bash", "setup.sh"])
print(f"{green}<< Setup completed >>{white}\n")

# Step 4: Dump OEM ZIP
print(f"{green}<< Dumping OEM ZIP >>{white}\n")
run_command(["./dumpyara.sh", OEMZIP])
print(f"{green}<< Dumping success >>{white}\n")

# Step 5: Clone essential extract tools
os.chdir("..")  # Go back to the main directory
print(f"{green}<< Cloning essential extracting tools >>{white}\n")
run_command(["git", "clone", "https://github.com/LineageOS/android_tools_extract-utils", 
             "-b", "lineage-21.0", "android/tools/extract-utils"])
run_command(["git", "clone", "https://github.com/LineageOS/android_prebuilts_extract-tools", 
             "-b", "lineage-21.0", "android/prebuilts/extract-tools"])

# Step 6: Clone device tree
print(f"{green}<< Cloning device tree >>{white}\n")
device_path = f"android/device/{DEVICENAME}"
run_command(["git", "clone", DT, device_path])
print(f"{green}<< Cloning success >>{white}\n")

# Step 7: Clone vendor tree
print(f"{green}<< Cloning vendor tree >>{white}\n")
vendor_path = f"android/vendor/{DEVICENAME}"
run_command(["git", "clone", VT, vendor_path])
print(f"{green}<< Cloning success >>{white}\n")

# Final message
print(f"{green}<< Dumpyara setup finished! Happy dumping :) >>{white}\n")

import os
import subprocess

# Function to run shell commands and handle errors
def run_command(command, shell=False):
    try:
        subprocess.run(command, shell=shell, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error: {e}")

def clone_repo(url, path, depth=None, branch=None):
    if os.path.exists(path):
        print(f"Old resource found in '{path}', deleting...")
        # Pass command as a list to avoid FileNotFoundError
        run_command(["rm", "-rf", path])  
    print(f"Cloning from {url} into '{path}'...")

    # Build the git command with depth and branch options if provided
    command = ["git", "clone"]
    if depth:
        command.extend(["--depth", str(depth)])
    if branch:
        command.extend(["--branch", branch])
    command.extend([url, path])

    try:
        subprocess.run(command, check=True)
        print(f"Successfully cloned '{path}'.")
    except subprocess.CalledProcessError:
        print(f"Failed to clone {url} into '{path}'.")

# Repository URLs and their respective clone paths
repos = {
    "device/xiaomi/sweet": "https://github.com/narikootam-dev/device_xiaomi_sweet",
    "vendor/xiaomi/sweet": "https://github.com/narikootam-dev/vendor_xiaomi_sweet",
    "kernel/xiaomi/sweet": "https://github.com/narikootam-dev/kernel_xiaomi_msm4.14",
    "vendor/xiaomi/sweet-miuicamera": "https://gitlab.com/mrfox2003/sweet-miuicamera",
    "hardware/dolby": "https://github.com/narikootam-dev/hardware_dolby",
    "hardware/xiaomi": "https://github.com/narikootam-dev/hardware_xiaomi",
    "$HOME/.android-certs": "https://github.com/yunluo-testzone/.android-certs",
    "vendor/voltage-priv/keys": "https://github.com/yunluo-testzone/vendor_voltage-priv_keys",
    "prebuilts/clang/host/linux-x86/trb_clang": "https://bitbucket.org/shuttercat/clang",
    "hardware/dolby": "https://github.com/narikootam-dev/hardware_dolby"
}

# Clone each repository with status messages
for path, url in repos.items():
    # If the repo is "clang", use --depth=1 and branch=14
    if path == "prebuilts/clang/host/linux-x86/trb_clang":
        clone_repo(url, path, depth=1, branch="14")
    else:
        clone_repo(url, path)

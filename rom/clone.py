import os
import subprocess

# Function to run shell commands and handle errors
def run_command(command, shell=False):
    """Executes a shell command and prints an error message if it fails."""
    try:
        # check=True raises CalledProcessError on non-zero exit status, which handles failures
        subprocess.run(command, shell=shell, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error: Command failed with return code {e.returncode} - {e}")
    except FileNotFoundError:
        # This occurs if shell=False and the command is not found in the system's PATH
        print(f"Error: Command not found or invalid path for: {' '.join(command)}")

def clone_repo(url, path, depth=None, branch=None):
    """
    Clones a Git repository, deleting the existing directory if present.

    Args:
        url (str): The remote repository URL.
        path (str): The local path to clone into.
        # Note: depth and branch arguments are included but will default to None,
        # ensuring all remaining repos perform a standard full clone.
        depth (int, optional): Depth for a shallow clone.
        branch (str, optional): Specific branch to checkout.
    """
    # 1. Clean up old directory if it exists
    if os.path.exists(path):
        print(f"Old resource found in '{path}', deleting...")
        # Use 'rm -rf' command to recursively force-delete the directory
        # Using run_command ensures error handling is consistent
        run_command(["rm", "-rf", path])
        
    print(f"Cloning from {url} into '{path}'...")

    # 2. Build the standard git clone command
    command = ["git", "clone"]
    
    # Although not used in the simplified loop, these options remain in the function signature
    # for future flexibility if a specific repo needed custom handling later.
    if depth:
        command.extend(["--depth", str(depth)])
    if branch:
        command.extend(["--branch", branch])
        
    command.extend([url, path])

    # 3. Execute the clone
    try:
        subprocess.run(command, check=True)
        print(f"Successfully cloned '{path}'.")
    except subprocess.CalledProcessError:
        print(f"Failed to clone {url} into '{path}'.")
        
# Repository URLs and their respective clone paths
repos = {
    "device/xiaomi/sweet": "https://github.com/narikootam-dev/device_xiaomi_sweet",
    "vendor/xiaomi/sweet": "https://github.com/narikootam-dev/vendor_xiaomi_sweet",
    "kernel/xiaomi/sweet": "https://github.com/narikootam-dev/kernel_xiaomi_sweet",
    "hardware/dolby": "https://github.com/narikootam-dev/hardware_dolby",
    "$HOME/.android-certs": "https://github.com/yunluo-testzone/.android-certs",
    "vendor/voltage-priv/keys": "https://github.com/mrfox2003/vendor_voltage-priv_keys",
    "vendor/oneplus/dolby": "https://github.com/narikootam-dev/vendor_oneplus_dolby",
    "device/xiaomi/miuicamera-sweet": "https://github.com/narikootam-dev/device-xiaomi-miuicamera-sweet",
    "vendor/xiaomi/miuicamera-sweet": "https://github.com/narikootam-dev/vendor_xiaomi_miuicamera-sweet"
}

# Clone each repository with standard settings (full clone of the default branch)
for path, url in repos.items():
    clone_repo(url, path)

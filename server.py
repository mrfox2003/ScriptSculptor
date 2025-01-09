import subprocess

def run_command(command):
    """Run a shell command and exit if it fails."""
    try:
        subprocess.run(command, shell=True, check=True)
        print(f"Successfully executed: {command}")
    except subprocess.CalledProcessError:
        print(f"Failed to execute: {command}")
        exit(1)

# Update and upgrade packages
run_command("sudo apt-get update && sudo apt-get upgrade -y")

# Install required packages
run_command("sudo apt-get install gnupg2 -y")
run_command("sudo apt-get install golang-go -y")

# Configure Git user details
run_command('git config --global user.name "Niranjan BR"')
run_command('git config --global user.email "niranjankannan2003@gmail.com"')

# Store Git credentials
run_command("git config --global credential.helper store")

# Add environment variable to .bashrc for Go PATH
run_command("echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc")

# Install additional dependencies
dependencies = (
    "bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs "
    "gperf imagemagick lib32readline-dev lib32z1-dev libelf-dev liblz4-tool "
    "libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool "
    "squashfs-tools xsltproc zip zlib1g-dev"
)
run_command(f"sudo apt-get install {dependencies} -y")

# Download and install libtinfo5
run_command("wget http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.4-2_amd64.deb")
run_command("sudo dpkg -i libtinfo5_6.4-2_amd64.deb")
run_command("rm -f libtinfo5_6.4-2_amd64.deb")

# Download and install libncurses5
run_command("wget http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.4-2_amd64.deb")
run_command("sudo dpkg -i libncurses5_6.4-2_amd64.deb")
run_command("rm -f libncurses5_6.4-2_amd64.deb")

print("Setup completed successfully!")

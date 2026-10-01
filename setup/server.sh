#!/usr/bin/env bash

set -e

echo "======================================"
echo "Android Build Environment"
echo "======================================"

# ------------------------------------------
# Update system
# ------------------------------------------

echo
echo "==> Updating system..."

sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y

# ------------------------------------------
# Install dependencies
# ------------------------------------------

echo
echo "==> Installing Android build dependencies..."

sudo DEBIAN_FRONTEND=noninteractive apt install -y \
    adb \
    aria2 \
    autoconf \
    automake \
    bc \
    bison \
    build-essential \
    clang \
    cmake \
    cpio \
    curl \
    device-tree-compiler \
    fastboot \
    fastfetch \
    flex \
    g++ \
    gcc \
    git \
    git-lfs \
    gnupg \
    gnupg2 \
    gperf \
    golang-go \
    htop \
    imagemagick \
    jq \
    lib32ncurses6 \
    lib32readline-dev \
    lib32z1 \
    lib32z1-dev \
    libc6-dev \
    libcap-dev \
    libelf-dev \
    libexpat1-dev \
    libgmp-dev \
    libmpc-dev \
    libmpfr-dev \
    libncurses-dev \
    libssl-dev \
    libtool \
    libxml2-utils \
    lld \
    lsof \
    lz4 \
    lzop \
    make \
    meson \
    nano \
    ncdu \
    ninja-build \
    openssh-client \
    openssl \
    p7zip-full \
    pahole \
    patch \
    patchelf \
    pigz \
    pngcrush \
    pngquant \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-pyelftools \
    python3-venv \
    python-is-python3 \
    re2c \
    ripgrep \
    rsync \
    schedtool \
    screen \
    socat \
    squashfs-tools \
    texinfo \
    tmux \
    tmate \
    tree \
    unzip \
    vim \
    wget \
    xsltproc \
    xz-utils \
    zip \
    zlib1g-dev \
    zstd \
    openjdk-17-jdk

# ------------------------------------------
# Git configuration
# ------------------------------------------

echo
echo "==> Configuring Git..."

git config --global user.name "Niranjan BR"
git config --global user.email "niranjankannan2003@gmail.com"
git config --global credential.helper store

# Git performance optimizations
git config --global core.fsmonitor true
git config --global core.untrackedCache true

# ------------------------------------------
# Git LFS
# ------------------------------------------

echo
echo "==> Configuring Git LFS..."

git lfs install

# ------------------------------------------
# GPG
# ------------------------------------------

echo
echo "==> Configuring GPG..."

if [ -f "k.asc" ]; then
    echo "Found k.asc, importing GPG key..."
    gpg --import k.asc
else
    echo "k.asc not found, skipping GPG key import."
fi

if ! grep -qF 'export GPG_TTY=$(tty)' ~/.bashrc; then
    echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
fi

export GPG_TTY=$(tty)

# ------------------------------------------
# Go
# ------------------------------------------

echo
echo "==> Configuring Go..."

if ! grep -qF 'export PATH=$PATH:$(go env GOPATH)/bin' ~/.bashrc; then
    echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
fi

export PATH="$PATH:$(go env GOPATH)/bin"

# ------------------------------------------
# GitHub CLI
# ------------------------------------------

echo
echo "==> Installing GitHub CLI..."

if command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI already installed. Skipping."
else
    curl -fsSL \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo dd \
        of=/usr/share/keyrings/githubcli-archive-keyring.gpg

    sudo chmod go+r \
        /usr/share/keyrings/githubcli-archive-keyring.gpg

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

    sudo apt update
    sudo apt install -y gh
fi

# ------------------------------------------
# Android udev rules
# ------------------------------------------

echo
echo "==> Installing Android udev rules..."

sudo curl \
    --create-dirs \
    -L \
    -o /etc/udev/rules.d/51-android.rules \
    https://raw.githubusercontent.com/M0Rf30/android-udev-rules/master/51-android.rules

sudo chmod 644 /etc/udev/rules.d/51-android.rules
sudo chown root:root /etc/udev/rules.d/51-android.rules

sudo udevadm control --reload-rules
sudo udevadm trigger

# ------------------------------------------
# ccache
# ------------------------------------------

echo
echo "==> Checking ccache..."

if command -v ccache >/dev/null 2>&1; then

    echo "ccache is already installed."
    echo "Skipping ccache compilation."

else

    echo "ccache is not installed."
    echo "Building ccache from source..."

    CCACHE_DIR="$(mktemp -d)"

    cleanup_ccache() {
        rm -rf "$CCACHE_DIR"
    }

    trap cleanup_ccache EXIT

    cd "$CCACHE_DIR"

    git clone --depth=1 https://github.com/ccache/ccache.git

    cd ccache

    mkdir -p build
    cd build

    cmake \
        -DHIREDIS_FROM_INTERNET=ON \
        -DZSTD_FROM_INTERNET=ON \
        -DCMAKE_BUILD_TYPE=Release \
        ..

    make -j"$(nproc)"

    sudo make install

    cd /

    echo
    echo "ccache installed successfully."

fi

# ------------------------------------------
# ccache configuration
# ------------------------------------------

echo
echo "==> Configuring ccache..."

ccache --set-config=compression=true
ccache --set-config=max_size=100G

if ! grep -qF 'export USE_CCACHE=1' ~/.bashrc; then
    echo 'export USE_CCACHE=1' >> ~/.bashrc
fi

if ! grep -qF 'export CCACHE_EXEC=' ~/.bashrc; then
    echo 'export CCACHE_EXEC=$(command -v ccache)' >> ~/.bashrc
fi

# ------------------------------------------
# Ninja configuration
# ------------------------------------------

echo
echo "==> Configuring Ninja..."

if ! grep -qF 'export NINJA_ARGS=' ~/.bashrc; then
    echo 'export NINJA_ARGS="-j$(nproc)"' >> ~/.bashrc
fi

# ------------------------------------------
# Repo
# ------------------------------------------

echo
echo "==> Installing repo..."

if command -v repo >/dev/null 2>&1; then

    echo "repo is already installed. Skipping."

else

    sudo curl \
        --create-dirs \
        -L \
        -o /usr/local/bin/repo \
        https://storage.googleapis.com/git-repo-downloads/repo

    sudo chmod a+rx /usr/local/bin/repo

fi

# ------------------------------------------
# Final verification
# ------------------------------------------

echo
echo "======================================"
echo " Installation completed!"
echo "======================================"

echo
echo "System:"
fastfetch

echo
echo "Installed tools:"
echo "--------------------------------------"

echo "Git:       $(git --version)"
echo "Git LFS:   $(git lfs version)"
echo "GitHub:    $(gh --version | head -n 1)"
echo "Python:    $(python3 --version)"
echo "Go:        $(go version)"
echo "Java:      $(java -version 2>&1 | head -n 1)"
echo "GCC:       $(gcc --version | head -n 1)"
echo "Clang:     $(clang --version | head -n 1)"
echo "CMake:     $(cmake --version | head -n 1)"
echo "Ninja:     $(ninja --version)"
echo "Repo:      $(repo --version | head -n 1)"
echo "ADB:       $(adb --version | head -n 1)"
echo "Fastboot:  $(fastboot --version | head -n 1)"
echo "DTC:       $(dtc --version)"
echo "LZ4:       $(lz4 --version | head -n 1)"
echo "Zstd:      $(zstd --version | head -n 1)"
echo "TMux:      $(tmux -V)"
echo "TMate:     $(tmate -V)"

# ------------------------------------------
# ccache statistics
# ------------------------------------------

echo
echo "======================================"
echo " ccache information"
echo "======================================"

echo
ccache --show-stats

echo
echo "ccache configuration:"
echo "--------------------------------------"

ccache --show-config | grep -E \
    'max_size|compression|cache_dir'

echo
echo "======================================"
echo " Setup completed successfully!"
echo "======================================"

echo
echo "Reload your shell:"
echo
echo "    source ~/.bashrc"
echo

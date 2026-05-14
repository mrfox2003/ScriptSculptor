#!/bin/bash
set -Eeuo pipefail
#Replace links accordingly

# Parse command-line flags
VARIANT="standard"
KERNEL_DIR="kernel"
KERNEL_BRANCH="16.0"
VARIANT_TAG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -ksu|--kernelsu)
            VARIANT="ksu"
            KERNEL_DIR="kernelsu"
            KERNEL_BRANCH="ksu-16.0"
            VARIANT_TAG="-KSU"
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [-ksu]"
            exit 1
            ;;
    esac
    shift
done

green='\033[0;32m'
white='\033[0m'

TG_CHAT="chat_token" 
TG_BOT="bot_token"
TG_TOPIC=""   # leave empty to post in main chat; set to topic ID (e.g., 6752) to post in a topic

error_log="$(mktemp /tmp/error.XXXXXX.log)"
build_log="$(mktemp /tmp/build.XXXXXX.log)"
build_status="$(mktemp /tmp/build_status.XXXXXX)"
exec > >(tee -a "$error_log") 2>&1

cleanup() {
    if [[ -n "${PROGRESS_WATCHER_PID:-}" ]]; then
        kill "$PROGRESS_WATCHER_PID" 2>/dev/null || true
    fi
    rm -f "$error_log"
    rm -f "$build_log"
    rm -f "$build_status"
}

on_error() {
    local exit_code="$1"
    local line_no="$2"

    trap - ERR
    set +e
    tg_post_msg "Kernel build failed at line $line_no (exit code: $exit_code)."
    tg_post_doc "$error_log"
    exit "$exit_code"
}

trap cleanup EXIT
trap 'on_error "$?" "$LINENO"' ERR

# Function to send message to Telegram
tg_post_msg() {
    local url="https://api.telegram.org/bot$TG_BOT/sendMessage"
    if [[ -n "$TG_TOPIC" ]]; then
        curl -s -X POST "$url" \
        -d chat_id="$TG_CHAT" \
        -d message_thread_id="$TG_TOPIC" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
    else
        curl -s -X POST "$url" \
        -d chat_id="$TG_CHAT" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
    fi
}

# Function to send document to Telegram
tg_post_doc() {
    local url="https://api.telegram.org/bot$TG_BOT/sendDocument"
    local caption="${2-}"
    if [[ -n "$TG_TOPIC" ]]; then
        curl --progress-bar -F document=@"$1" "$url" \
        -F chat_id="$TG_CHAT" \
        -F message_thread_id="$TG_TOPIC" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$caption"
    else
        curl --progress-bar -F document=@"$1" "$url" \
        -F chat_id="$TG_CHAT"  \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$caption"
    fi
}

tg_post_msg_id() {
    local url="https://api.telegram.org/bot$TG_BOT/sendMessage"
    local response

    if [[ -n "$TG_TOPIC" ]]; then
        response=$(curl -s -X POST "$url" \
            -d chat_id="$TG_CHAT" \
            -d message_thread_id="$TG_TOPIC" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1")
    else
        response=$(curl -s -X POST "$url" \
            -d chat_id="$TG_CHAT" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1")
    fi

    echo "$response" | jq -r '.result.message_id'
}

tg_edit_msg() {
    local url="https://api.telegram.org/bot$TG_BOT/editMessageText"

    if [[ -n "$TG_TOPIC" ]]; then
        curl -s -X POST "$url" \
            -d chat_id="$TG_CHAT" \
            -d message_thread_id="$TG_TOPIC" \
            -d message_id="$2" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1" >/dev/null
    else
        curl -s -X POST "$url" \
            -d chat_id="$TG_CHAT" \
            -d message_id="$2" \
            -d "disable_web_page_preview=true" \
            -d "parse_mode=html" \
            -d text="$1" >/dev/null
    fi
}

escape_html() {
    sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

fetch_progress() {
    local progress
    progress="$(
        tail -n 6 "$build_log" 2>/dev/null | sed '/^$/d' || true
    )"

    if [[ -z "$progress" ]]; then
        echo "Initializing the build system..."
    else
        printf '%s\n' "$progress"
    fi
}

start_progress_watcher() {
    local message_id="$1"

    (
        local previous_progress=""

        while [[ ! -s "$build_status" ]]; do
            local current_progress
            current_progress="$(fetch_progress)"

            if [[ "$current_progress" != "$previous_progress" ]]; then
                local progress_message
                progress_message=$(printf '🟡 | <i>Compiling Kernel...</i>\n\n<pre>%s</pre>' "$(printf '%s\n' "$current_progress" | escape_html)")
                tg_edit_msg "$progress_message" "$message_id"
                previous_progress="$current_progress"
            fi

            sleep 5
        done
    ) &

    PROGRESS_WATCHER_PID=$!
}

# Function to pin a message in Telegram 
pin_message() {
    curl -s -X POST "https://api.telegram.org/bot$TG_BOT/pinChatMessage" \
    -d chat_id="$1" \
    -d message_id="$2"
}

# Initialize Toolchains
echo -e "$green Checking for GCC directories... $white"
if [ -d "$HOME/kernel-compiler/gcc64" ] && [ -d "$HOME/kernel-compiler/gcc32" ]; then
    echo -e "$green GCC directories already exist. Skipping clone. $white"
else
    echo -e "$green Cloning GCC toolchains... $white"
    git clone --depth=1 https://github.com/mvaisakh/gcc-arm64 "$HOME"/kernel-compiler/gcc64
    git clone --depth=1 https://github.com/mvaisakh/gcc-arm "$HOME"/kernel-compiler/gcc32
    echo -e "$green GCC toolchains cloned successfully. $white"
fi

# Initialize Clang
echo -e "$green Checking for Clang directory... $white"
if [ -d "$HOME/kernel-compiler/clang" ]; then
    echo -e "$green Clang directory already exists. Skipping clone. $white"
else
    echo -e "$green Cloning Clang... $white"
    git clone -b main --depth=1  https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 "$HOME"/kernel-compiler/clang
    echo -e "$green Clang cloned successfully. $white"
fi

# Initialize Kernel
echo -e "$green Checking for Kernel directory... $white"
if [ -d "$KERNEL_DIR" ]; then
    echo -e "$green Kernel directory '$KERNEL_DIR' already exists. Skipping clone. $white"
else
    echo -e "$green Cloning Kernel repository... $white"
    git clone https://github.com/narikootam-dev/kernel_xiaomi_sweet -b "$KERNEL_BRANCH" "$KERNEL_DIR"
    echo -e "$green Kernel repository cloned successfully. $white"
fi

# Begin kernel compilation
cd "$KERNEL_DIR"
MY_DIR="$(pwd)"
KERNEL_DEFCONFIG=vendor/sweet_user_defconfig
date=$(date +"%Y-%m-%d-%H%M")
export ARCH=arm64
export SUBARCH=arm64
export zipname="MerakiKernel${VARIANT_TAG}-sweet-${date}.zip"
export PATH="$HOME/kernel-compiler/gcc64/bin:$HOME/kernel-compiler/gcc32/bin:$PATH"
export STRIP="$HOME/kernel-compiler/gcc64/aarch64-elf/bin/strip"
export KBUILD_COMPILER_STRING=$("$HOME"/kernel-compiler/gcc64/bin/aarch64-elf-gcc --version | head -n 1)
export PATH="$HOME/kernel-compiler/clang/clang-r547379/bin:$PATH"
export KBUILD_COMPILER_STRING=$("$HOME"/kernel-compiler/clang/clang-r547379/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

# Notify Telegram about the start of compilation
tg_post_msg "Kernel${VARIANT_TAG:+ $VARIANT_TAG} compilation started for device 'Sweet'."
COMMIT=$(git log --pretty=format:"%s" -5)
tg_post_msg "<b>Recent Changelogs:</b>%0A$COMMIT"

# Speed up build process
MAKE="./makeparallel"
BUILD_START=$(date +"%s")
blue='\033[0;34m'
cyan='\033[0;36m'
yellow='\033[0;33m'
red='\033[0;31m'
nocol='\033[0m'

echo "**** Kernel defconfig set to $KERNEL_DEFCONFIG ****"
echo -e "$blue***********************************************"
echo "          STARTING KERNEL BUILD          "
echo -e "***********************************************$nocol"
build_message_id=$(tg_post_msg_id "$(printf '🟡 | <i>Compiling Kernel...</i>\n\n<pre>Initializing the build system...</pre>')")
start_progress_watcher "$build_message_id"

(
    set -o pipefail
    make $KERNEL_DEFCONFIG O=out CC=clang 2>&1 | tee -a "$build_log"
    defconfig_status=$?

    if [[ "$defconfig_status" -ne 0 ]]; then
        printf '%s\n' "$defconfig_status" > "$build_status"
        exit 0
    fi

    make -j"$(nproc --all)" O=out \
                              ARCH=arm64 \
                              LLVM=1 \
                              LLVM_IAS=1 \
                              AR=llvm-ar \
                              NM=llvm-nm \
                              LD=ld.lld \
                              OBJCOPY=llvm-objcopy \
                              OBJDUMP=llvm-objdump \
                              STRIP=llvm-strip \
                              CC=clang \
                              CROSS_COMPILE=aarch64-linux-gnu- \
                              CROSS_COMPILE_ARM32=arm-linux-gnueabi- 2>&1 | tee -a "$build_log"
    printf '%s\n' "$?" > "$build_status"
)

make_status=$(cat "$build_status")
if [[ -n "${PROGRESS_WATCHER_PID:-}" ]]; then
    kill "$PROGRESS_WATCHER_PID" 2>/dev/null || true
    wait "$PROGRESS_WATCHER_PID" 2>/dev/null || true
fi

if [[ "$make_status" -ne 0 ]]; then
    tg_post_msg "Kernel build failed."
    tg_post_doc "$error_log"
    exit "$make_status"
fi

require_file() {
    [[ -f "$1" ]]
}

require_file out/arch/arm64/boot/Image.gz
require_file out/arch/arm64/boot/dtbo.img

export IMG="$MY_DIR"/out/arch/arm64/boot/Image.gz
export dtbo="$MY_DIR"/out/arch/arm64/boot/dtbo.img
export dtb="$MY_DIR"/out/arch/arm64/boot/dtb.img

find out/arch/arm64/boot/dts/ -name '*.dtb' -exec cat {} + >out/arch/arm64/boot/dtb
require_file out/arch/arm64/boot/dtb
git clone -q https://github.com/narikootam-dev/AnyKernel3
cp out/arch/arm64/boot/Image.gz AnyKernel3
cp out/arch/arm64/boot/dtb AnyKernel3
cp out/arch/arm64/boot/dtbo.img AnyKernel3
rm -f *zip
cd AnyKernel3
sed -i "s/is_slot_device=0/is_slot_device=auto/g" anykernel.sh
zip -r9 "../${zipname}" * -x '*.git*' README.md *placeholder >> /dev/null
cd ..
rm -rf AnyKernel3
echo -e "Build completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
tg_post_msg "Build completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!"
echo ""
echo -e "Kernel package '${zipname}' is ready!"
echo ""
if [[ -n "$TG_TOPIC" ]]; then
    BUILD_MSG=$(curl -s -X POST "https://api.telegram.org/bot$TG_BOT/sendMessage" \
        -d chat_id="$TG_CHAT" \
        -d message_thread_id="$TG_TOPIC" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="Kernel package '${zipname}' is ready!")
else
    BUILD_MSG=$(curl -s -X POST "https://api.telegram.org/bot$TG_BOT/sendMessage" \
        -d chat_id="$TG_CHAT" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="Kernel package '${zipname}' is ready!")
fi
BUILD_MSG_ID=$(echo "$BUILD_MSG" | jq -r '.result.message_id') 
pin_message "$TG_CHAT" "$BUILD_MSG_ID"
rm -rf out
tg_post_doc "${zipname}"
rm -rf ${zipname}

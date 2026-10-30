#!/bin/bash
set -Eeuo pipefail
#Replace links accordingly

# Parse command-line flags
VARIANT="standard"
KERNEL_DIR="kernel"
KERNEL_BRANCH="17.0"
VARIANT_TAG=""
KSU_VERSION=""
KSU_APK_URL=""
KSU_APK_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -ksu|--kernelsu)
            VARIANT="ksu"
            KERNEL_DIR="kernelsu"
            KERNEL_BRANCH="ksu-17.0"
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

if [[ "$VARIANT" == "ksu" ]]; then
    BUILD_LABEL="KernelSU"
else
    BUILD_LABEL="Standard"
fi

green='\033[0;32m'
red='\033[0;31m'
white='\033[0m'

TG_CHAT="chat_token" 
TG_BOT="bot_token"
TG_TOPIC=""   # leave empty to post in main chat; set to topic ID (e.g., 6752) to post in a topic

error_dir="$(mktemp -d /tmp/error.XXXXXX)"
error_log="${error_dir}/error.log"
build_log="$(mktemp /tmp/build.XXXXXX.log)"
build_status="$(mktemp /tmp/build_status.XXXXXX)"

cleanup() {
    if [[ -n "${PROGRESS_WATCHER_PID:-}" ]]; then
        kill "$PROGRESS_WATCHER_PID" 2>/dev/null || true
    fi
    rm -rf "$error_dir"
    rm -f "$build_log"
    rm -f "$build_status"
    [[ -n "${KSU_APK_NAME:-}" ]] && rm -f "$KSU_APK_NAME"
}

create_error_report() {
    local stage="$1"
    local exit_code="$2"
    local line_no="${3-}"
    local failed_cmd="${4-}"

    {
        echo "========================================"
        echo "Meraki Kernel Build Failure"
        echo "========================================"
        echo
        echo "Variant:     $BUILD_LABEL"
        echo "Branch:      $KERNEL_BRANCH"
        echo "Directory:   $KERNEL_DIR"
        echo "Stage:       $stage"
        echo "Exit code:   $exit_code"
        [[ -n "$line_no" ]] && echo "Line:        $line_no"
        [[ -n "$failed_cmd" ]] && echo "Command:     $failed_cmd"
        echo

        echo "========================================"
        echo "Relevant errors"
        echo "========================================"

        if ! grep -Ei \
            '(^|[[:space:]])(error:|fatal error:|Error:|FAILED:|undefined reference|No such file or directory|collect2: error:)' \
            "$build_log" | tail -n 80; then
            echo "No matching compiler error lines were found."
        fi

        echo
        echo "========================================"
        echo "Full build log"
        echo "========================================"
        if [[ -s "$build_log" ]]; then
            cat "$build_log"
        else
            echo "No build output was captured."
        fi
    } > "$error_log"
}

report_failure() {
    local exit_code="$1"
    local stage="$2"
    local line_no="${3-}"
    local failed_cmd="${4-}"

    # Disable ERR handling while reporting so one failure produces one report.
    trap - ERR
    set +e

    create_error_report "$stage" "$exit_code" "$line_no" "$failed_cmd"

    tg_post_msg "$(printf '🔴 | <b>%s kernel build failed</b>\n<b>Stage:</b> <code>%s</code>\n<b>Exit code:</b> <code>%s</code>%s%s\n<b>Branch:</b> <code>%s</code>\n<b>Dir:</b> <code>%s</code>' \
        "$BUILD_LABEL" \
        "$stage" \
        "$exit_code" \
        "$(if [[ -n "$line_no" ]]; then printf '\n<b>Line:</b> <code>%s</code>' "$line_no"; fi)" \
        "$(if [[ -n "$failed_cmd" ]]; then printf '\n<b>Command:</b> <code>%s</code>' "$failed_cmd"; fi)" \
        "$KERNEL_BRANCH" \
        "$KERNEL_DIR")"
    tg_post_doc "$error_log" "❌ <b>Build Error Log:</b> <code>error.log</code>"
    exit "$exit_code"
}

on_error() {
    local exit_code="$1"
    local line_no="$2"
    local failed_cmd="${3-}"

    report_failure "$exit_code" "script error" "$line_no" "$failed_cmd"
}

trap cleanup EXIT
trap 'on_error "$?" "$LINENO" "$BASH_COMMAND"' ERR

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
                progress_message=$(printf '🟡 | <i>Compiling %s kernel...</i>\n<b>Branch:</b> <code>%s</code> | <b>Dir:</b> <code>%s</code>\n\n<pre>%s</pre>' "$BUILD_LABEL" "$KERNEL_BRANCH" "$KERNEL_DIR" "$(printf '%s\n' "$current_progress" | escape_html)")
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

# Integrate KernelSU only for the -ksu variant
if [[ "$VARIANT" == "ksu" ]]; then
    echo -e "$green Integrating KernelSU... $white"
    KSU_RELEASE_JSON=$(curl -s https://api.github.com/repos/backslashxx/KernelSU/releases/latest)
    KSU_VERSION=$(jq -r .tag_name <<< "$KSU_RELEASE_JSON")
    KSU_APK_URL=$(jq -r '.assets[] | select(.name | test("\\.apk$"; "i")) | .browser_download_url' <<< "$KSU_RELEASE_JSON" | head -n1)
    KSU_APK_NAME=$(basename "$KSU_APK_URL" 2>/dev/null || true)

    echo "📌 Fetching KernelSU Tag: $KSU_VERSION"
    if [[ -n "$KSU_APK_URL" && "$KSU_APK_URL" != "null" ]]; then
        echo "📱 KernelSU APK found: $KSU_APK_NAME"
    else
        echo "⚠️ No KernelSU APK asset found in latest release"
        KSU_APK_URL=""
        KSU_APK_NAME=""
    fi

    curl -LSs "https://raw.githubusercontent.com/backslashxx/KernelSU/refs/heads/master/kernel/setup.sh" | bash -s -- "$KSU_VERSION"

    # Integrate NoMount
    echo -e "$green Setting up NoMount... $white"
    curl -LSs "https://raw.githubusercontent.com/maxsteeel/nomount/refs/heads/dev/kernel/setup.sh" | bash -

    echo -e "$green Validating NoMount integration... $white"

    if [[ ! -d "fs/nomount" ]]; then
        echo -e "${red}❌ NoMount source directory was not created.${white}"
        report_failure 1 "nomount setup (fs/nomount missing)"
    fi

    if [[ ! -f "fs/nomount/Kconfig" ]]; then
        echo -e "${red}❌ NoMount Kconfig not found.${white}"
        report_failure 1 "nomount setup (fs/nomount/Kconfig missing)"
    fi

    if [[ ! -f "fs/nomount/Makefile" ]]; then
        echo -e "${red}❌ NoMount Makefile not found.${white}"
        report_failure 1 "nomount setup (fs/nomount/Makefile missing)"
    fi

    if ! grep -Fq 'source "fs/nomount/Kconfig"' fs/Kconfig; then
        echo -e "${red}❌ fs/Kconfig is missing NoMount Kconfig integration.${white}"
        report_failure 1 "nomount setup (fs/Kconfig integration missing)"
    fi

    if ! grep -Fq 'obj-$(CONFIG_NOMOUNT)' fs/Makefile; then
        echo -e "${red}❌ fs/Makefile is missing NoMount integration.${white}"
        report_failure 1 "nomount setup (fs/Makefile integration missing)"
    fi

    echo -e "$green✅ NoMount source and kernel integration detected.$white"
fi

KERNEL_DEFCONFIG=vendor/sweet_user_defconfig
date=$(date +"%Y-%m-%d-%H%M")
export ARCH=arm64
export SUBARCH=arm64
export zipname="MerakiKernel${VARIANT_TAG}-sweet-${date}.zip"
export PATH="$HOME/kernel-compiler/clang/clang-r547379/bin:$PATH"
export KBUILD_COMPILER_STRING=$("$HOME"/kernel-compiler/clang/clang-r547379/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')

# Explicit ccache configuration
if ! command -v ccache >/dev/null 2>&1; then
    echo "ERROR: ccache is not installed or not in PATH."
    exit 1
fi

export CCACHE_EXEC="$(command -v ccache)"
export CCACHE_BASEDIR="$MY_DIR"
ccache --set-config=compression=true >/dev/null
ccache --set-config=max_size=100G >/dev/null

# Use ccache explicitly in front of Clang for every C compilation.
# LLVM=1 is still used so Kbuild uses the LLVM binutils/toolchain.
export CC="ccache clang"

ccache --show-config | grep -E 'cache_dir|max_size|compression' || true
ccache --show-stats || true

# Notify Telegram about the start of compilation
tg_post_msg "$(printf '🚀 | <b>%s kernel build started</b>\n<b>Device:</b> <code>sweet</code>\n<b>Branch:</b> <code>%s</code>\n<b>Dir:</b> <code>%s</code>\n<b>Defconfig:</b> <code>%s</code>' "$BUILD_LABEL" "$KERNEL_BRANCH" "$KERNEL_DIR" "$KERNEL_DEFCONFIG")"
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
build_message_id=$(tg_post_msg_id "$(printf '🟡 | <i>Compiling %s kernel...</i>\n<b>Branch:</b> <code>%s</code> | <b>Dir:</b> <code>%s</code>\n\n<pre>Initializing the build system...</pre>' "$BUILD_LABEL" "$KERNEL_BRANCH" "$KERNEL_DIR")")
start_progress_watcher "$build_message_id"

(
    # Kernel build failures are expected conditions and are handled explicitly.
    # Keep ERR trapping for unexpected script failures only.
    set +e
    set -o pipefail

    make "$KERNEL_DEFCONFIG" O=out CC="$CC" 2>&1 | tee -a "$build_log"
    defconfig_status="${PIPESTATUS[0]}"

    if [[ "$defconfig_status" -ne 0 ]]; then
        printf 'defconfig:%s\n' "$defconfig_status" > "$build_status"
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
                              CC="$CC" \
                              2>&1 | tee -a "$build_log"
    make_status="${PIPESTATUS[0]}"
    printf 'kernel:%s\n' "$make_status" > "$build_status"

)

build_result=$(cat "$build_status")
failure_stage="${build_result%%:*}"
make_status="${build_result#*:}"
if [[ -n "${PROGRESS_WATCHER_PID:-}" ]]; then
    kill "$PROGRESS_WATCHER_PID" 2>/dev/null || true
    wait "$PROGRESS_WATCHER_PID" 2>/dev/null || true
fi

if [[ "$make_status" -ne 0 ]]; then
    case "$failure_stage" in
        defconfig)
            failure_stage="defconfig"
            ;;
        kernel)
            if [[ "$make_status" -eq 130 ]]; then
                failure_stage="kernel compilation interrupted"
            else
                failure_stage="kernel compilation"
            fi
            ;;
        *)
            failure_stage="kernel build"
            ;;
    esac

    report_failure "$make_status" "$failure_stage"
fi

echo
echo "======================================"
echo " ccache statistics"
echo "======================================"
ccache --show-stats || true

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
BUILD_ELAPSED="$((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)"
echo -e "Build completed in ${BUILD_ELAPSED}!"
tg_post_msg "$(printf '✅ | <b>%s kernel build completed</b>\n<b>Device:</b> <code>sweet</code>\n<b>Branch:</b> <code>%s</code>\n<b>Duration:</b> <code>%s</code>' "$BUILD_LABEL" "$KERNEL_BRANCH" "$BUILD_ELAPSED")"
echo ""
echo -e "Kernel package '${zipname}' is ready!"
echo ""
if [[ -n "$TG_TOPIC" ]]; then
    BUILD_MSG=$(curl -s -X POST "https://api.telegram.org/bot$TG_BOT/sendMessage" \
        -d chat_id="$TG_CHAT" \
        -d message_thread_id="$TG_TOPIC" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="📦 | <b>Package ready</b>%0A<b>Variant:</b> <code>${BUILD_LABEL}</code>%0A<b>Artifact:</b> <code>${zipname}</code>")
else
    BUILD_MSG=$(curl -s -X POST "https://api.telegram.org/bot$TG_BOT/sendMessage" \
        -d chat_id="$TG_CHAT" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="📦 | <b>Package ready</b>%0A<b>Variant:</b> <code>${BUILD_LABEL}</code>%0A<b>Artifact:</b> <code>${zipname}</code>")
fi
BUILD_MSG_ID=$(echo "$BUILD_MSG" | jq -r '.result.message_id') 
pin_message "$TG_CHAT" "$BUILD_MSG_ID"
rm -rf out
tg_post_doc "${zipname}"
rm -rf ${zipname}

# Post KernelSU Manager APK if build succeeded for -ksu variant
if [[ "$VARIANT" == "ksu" && -n "${KSU_APK_URL:-}" && "${KSU_APK_URL:-}" != "null" ]]; then
    echo -e "$green Downloading KernelSU Manager APK ($KSU_APK_NAME)... $white"
    if curl -sL "$KSU_APK_URL" -o "$KSU_APK_NAME"; then
        echo -e "$green Uploading KernelSU Manager APK to Telegram... $white"
        tg_post_doc "$KSU_APK_NAME" "📱 <b>KernelSU Manager (${KSU_VERSION})</b>"
        rm -f "$KSU_APK_NAME"
    else
        echo "⚠️ Failed to download KernelSU Manager APK from $KSU_APK_URL"
    fi
fi

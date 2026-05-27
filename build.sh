#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="${PROJECT_DIR}/output"

echo "============================================"
echo "  HostUpdater OpenWrt Package Builder"
echo "============================================"
echo ""
echo "Select build target:"
echo "  1) Stable 24.10.0 (.ipk) - Fast (Tsinghua mirror)"
echo "  2) SNAPSHOT (.apk)       - For OpenWrt 25.12+ (Official server)"
echo ""

# Support command line argument or interactive selection
if [ "$1" = "apk" ] || [ "$1" = "snapshot" ]; then
    CHOICE="2"
elif [ "$1" = "ipk" ] || [ "$1" = "stable" ]; then
    CHOICE="1"
else
    read -p "Enter choice [1-2] (default: 1): " CHOICE
    CHOICE=${CHOICE:-1}
fi

mkdir -p "${OUTPUT_DIR}"

case "${CHOICE}" in
    2)
        SDK_URL="https://downloads.openwrt.org/snapshots/targets/x86/64/openwrt-sdk-x86-64_gcc-14.3.0_musl.Linux-x86_64.tar.zst"
        FORMAT="apk"
        echo ""
        echo "Selected: SNAPSHOT (.apk format)"
        echo "Note: Downloading from official OpenWrt server (may take a while)"
        ;;
    *)
        SDK_URL="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.0/targets/x86/64/openwrt-sdk-24.10.0-x86-64_gcc-13.3.0_musl.Linux-x86_64.tar.zst"
        FORMAT="ipk"
        echo ""
        echo "Selected: Stable 24.10.0 (.ipk format)"
        echo "Using Tsinghua mirror for fast download"
        ;;
esac

echo "SDK URL: ${SDK_URL}"
echo ""

docker build \
    --build-arg SDK_URL="${SDK_URL}" \
    -t hostupdater-builder "${PROJECT_DIR}"

echo ""
echo "Extracting packages from build container..."

CONTAINER_ID=$(docker create hostupdater-builder)
docker cp "${CONTAINER_ID}:/build/sdk/bin/." "${OUTPUT_DIR}"
docker rm "${CONTAINER_ID}" > /dev/null

echo ""
echo "============================================"
echo "  Build Complete!"
echo "============================================"
echo ""
echo "Packages are in: ${OUTPUT_DIR}/"
echo ""
find "${OUTPUT_DIR}" -name "*.${FORMAT}" 2>/dev/null | while read f; do
    ls -lh "$f"
done
echo ""

if [ "${FORMAT}" = "apk" ]; then
    echo "To install on OpenWrt SNAPSHOT (25.12+):"
    echo "  apk add output/hostupdater_*.apk"
else
    echo "To install on OpenWrt 24.10:"
    echo "  opkg install output/hostupdater_*.ipk"
fi

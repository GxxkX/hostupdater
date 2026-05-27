#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_OUTPUT_DIR="${PROJECT_DIR}/test-output"
VERSIONS=("24.10.0" "23.05.5" "22.03.7" "21.02.7" "19.07.10")
FAILED_VERSIONS=""

echo "============================================"
echo "  HostUpdater 多版本兼容性测试"
echo "============================================"
echo ""

mkdir -p "${TEST_OUTPUT_DIR}"

for VERSION in "${VERSIONS[@]}"; do
    echo ""
    echo "============================================"
    echo "  测试 OpenWrt ${VERSION}"
    echo "============================================"
    echo ""
    
    VERSION_OUTPUT_DIR="${TEST_OUTPUT_DIR}/${VERSION}"
    mkdir -p "${VERSION_OUTPUT_DIR}"
    
    # Determine SDK URL and target architecture
    case "${VERSION}" in
        24.10.0)
            SDK_URL="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.0/targets/x86/64/openwrt-sdk-24.10.0-x86-64_gcc-13.3.0_musl.Linux-x86_64.tar.zst"
            FORMAT="ipk"
            ;;
        23.05.5)
            SDK_URL="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/23.05.5/targets/x86/64/openwrt-sdk-23.05.5-x86-64_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
            FORMAT="ipk"
            ;;
        22.03.7)
            SDK_URL="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/22.03.7/targets/x86/64/openwrt-sdk-22.03.7-x86-64_gcc-11.2.0_musl.Linux-x86_64.tar.xz"
            FORMAT="ipk"
            ;;
        21.02.7)
            SDK_URL="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/21.02.7/targets/x86/64/openwrt-sdk-21.02.7-x86-64_gcc-8.4.0_musl.Linux-x86_64.tar.xz"
            FORMAT="ipk"
            ;;
        19.07.10)
            SDK_URL="https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/19.07.10/targets/x86/64/openwrt-sdk-19.07.10-x86-64_gcc-7.5.0_musl.Linux-x86_64.tar.xz"
            FORMAT="ipk"
            ;;
        *)
            echo "Unknown version: ${VERSION}"
            FAILED_VERSIONS="${FAILED_VERSIONS} ${VERSION}"
            continue
            ;;
    esac
    
    echo "SDK URL: ${SDK_URL}"
    echo "Output dir: ${VERSION_OUTPUT_DIR}"
    echo ""
    
    # Build Docker image
    IMAGE_TAG="hostupdater-test-${VERSION//./_}"
    
    if ! docker build \
        --build-arg SDK_URL="${SDK_URL}" \
        --build-arg OPENWRT_VERSION="${VERSION}" \
        -t "${IMAGE_TAG}" \
        -f "${PROJECT_DIR}/Dockerfile.test" \
        "${PROJECT_DIR}"; then
        echo "Docker build failed for OpenWrt ${VERSION}"
        FAILED_VERSIONS="${FAILED_VERSIONS} ${VERSION}"
        continue
    fi
    
    echo ""
    echo "Extracting build artifacts..."
    
    CONTAINER_ID=$(docker create "${IMAGE_TAG}")
    
    # Extract compile logs first (before removing container)
    docker cp "${CONTAINER_ID}:/tmp/compile.log" "${VERSION_OUTPUT_DIR}/compile.log" 2>/dev/null || true
    docker cp "${CONTAINER_ID}:/tmp/defconfig.log" "${VERSION_OUTPUT_DIR}/defconfig.log" 2>/dev/null || true
    docker cp "${CONTAINER_ID}:/build/sdk/bin/compile.log" "${VERSION_OUTPUT_DIR}/compile_fallback.log" 2>/dev/null || true
    
    # Try multiple paths for artifacts
    docker cp "${CONTAINER_ID}:/build/sdk/bin/packages/x86_64/base/." "${VERSION_OUTPUT_DIR}" 2>/dev/null || \
    docker cp "${CONTAINER_ID}:/build/sdk/bin/packages/." "${VERSION_OUTPUT_DIR}" 2>/dev/null || \
    docker cp "${CONTAINER_ID}:/build/sdk/bin/." "${VERSION_OUTPUT_DIR}" 2>/dev/null || true
    
    docker rm "${CONTAINER_ID}" > /dev/null
    
    echo ""
    echo "Checking results..."
    
    if find "${VERSION_OUTPUT_DIR}" -name "*.${FORMAT}" 2>/dev/null | grep -q .; then
        echo "OK OpenWrt ${VERSION} build successful"
        find "${VERSION_OUTPUT_DIR}" \( -name "*.ipk" -o -name "*.apk" \) -exec ls -lh {} \;
    else
        echo "FAIL OpenWrt ${VERSION} build failed"
        echo "Check log file: ${VERSION_OUTPUT_DIR}/compile.log"
        FAILED_VERSIONS="${FAILED_VERSIONS} ${VERSION}"
    fi
    
    echo ""
done

echo ""
echo "============================================"
echo "  Test completed"
echo "============================================"
echo ""

if [ -n "${FAILED_VERSIONS}" ]; then
    echo "Failed versions:${FAILED_VERSIONS}"
    exit 1
else
    echo "All versions built successfully!"
fi

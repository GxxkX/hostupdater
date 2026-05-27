FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's|archive.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g; s|security.ubuntu.com|mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources && \
    apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ccache \
    ecj \
    fastjar \
    file \
    g++ \
    gawk \
    gettext \
    git \
    java-propose-classpath \
    libelf-dev \
    libncurses5-dev \
    libncursesw5-dev \
    libssl-dev \
    python3 \
    python3-dev \
    python3-setuptools \
    rsync \
    unzip \
    wget \
    xsltproc \
    zlib1g-dev \
    zstd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG SDK_URL=https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/24.10.0/targets/x86/64/openwrt-sdk-24.10.0-x86-64_gcc-13.3.0_musl.Linux-x86_64.tar.zst

RUN wget -q "${SDK_URL}" -O sdk.tar.zst && \
    tar --zstd -xf sdk.tar.zst && \
    mv openwrt-sdk-* sdk && \
    rm sdk.tar.zst

WORKDIR /build/sdk

COPY ./Makefile ./package/hostupdater/
COPY ./files/ ./package/hostupdater/files/
COPY ./luasrc/ ./package/hostupdater/luasrc/
COPY ./po/ ./package/hostupdater/po/
COPY ./LICENSE ./package/hostupdater/

RUN make defconfig && \
    make package/hostupdater/compile V=s -j$(nproc)

CMD ["/bin/bash", "-c", "find bin -name '*.apk' -o -name '*.ipk' | head -20"]

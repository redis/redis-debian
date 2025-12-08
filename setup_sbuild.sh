#!/bin/bash
if [ $# != 2 ]; then
    echo "Please use: setup_build.sh [dist] [arch]"
    exit 1
fi

dist="$1"
arch="$2"
host_arch=$(dpkg --print-architecture)

echo "Setting up sbuild environment for distribution: $dist, architecture: $arch (host: $host_arch)"

if ubuntu-distro-info --all | grep -Fqx "$dist"; then
    disttype="ubuntu"
else
    disttype="debian"
fi

# Determine base apt repository URL based on type of distribution and architecture.
case "$disttype" in
    ubuntu)
        if [ "$arch" = "arm64" ] || [ "$arch" = "armhf" ]; then
            url=http://ports.ubuntu.com/ubuntu-ports
        else
            url=http://archive.ubuntu.com/ubuntu
        fi
         ;;
    debian)
        url=http://deb.debian.org/debian
        ;;
    *)
        echo "Unknown distribution $disttype"
        exit 1
esac

# Create a temporary file for the sbuild configuration
SBUILD_CONF=$(mktemp)
cat > "$SBUILD_CONF" << EOF
$host_arch $arch $dist $url
EOF

# Create the sbuild chroot with the configuration
sbuild-createchroot --arch=${arch} --make-sbuild-tarball=/var/lib/sbuild/${dist}-${arch}.tar.gz ${dist} $(mktemp -d) ${url}

# For cross-compilation, install the necessary packages
if [ "$arch" != "$host_arch" ]; then
    echo "Setting up cross-compilation environment from $host_arch to $arch"

    # Install cross-compilation tools in the chroot
    schroot -c source:${dist}-${arch}-sbuild -d / -- apt-get update
    schroot -c source:${dist}-${arch}-sbuild -d / -- apt-get install -y crossbuild-essential-${arch}

    # Create a file to tell sbuild this is a cross-compilation environment
    schroot -c source:${dist}-${arch}-sbuild -d / -- touch /etc/sbuild-cross-building
fi

# Ubuntu has the main and ports repositories on different URLs, so we need to
# properly set up /etc/apt/sources.list to make cross compilation work
# and enable multi-architecture support inside a chroot environment
if [ "$disttype" = "ubuntu" ]; then
    # Enable multiarch but don't try to install Python and other build tools for target arch
    schroot -c source:${dist}-${arch}-sbuild -d / -- dpkg --add-architecture i386
    schroot -c source:${dist}-${arch}-sbuild -d / -- dpkg --add-architecture armhf
    schroot -c source:${dist}-${arch}-sbuild -d / -- dpkg --add-architecture arm64
    # Update /etc/apt/sources.list for cross-compilation (Ubuntu)
    cat <<__END__ | schroot -c source:${dist}-${arch}-sbuild -d / -- tee /etc/apt/sources.list
deb [arch=amd64,i386] http://archive.ubuntu.com/ubuntu ${dist} main universe
deb [arch=amd64,i386] http://archive.ubuntu.com/ubuntu ${dist}-updates main universe
deb [arch=armhf,arm64] http://ports.ubuntu.com${ubuntu_ports} ${dist} main universe
deb [arch=armhf,arm64] http://ports.ubuntu.com${ubuntu_ports} ${dist}-updates main universe
__END__

elif [ "$disttype" = "debian" ]; then
#   enable multi-architecture support inside a chroot environment
    schroot -c source:${dist}-${arch}-sbuild -d / -- dpkg --add-architecture i386
    schroot -c source:${dist}-${arch}-sbuild -d / -- dpkg --add-architecture armhf
    schroot -c source:${dist}-${arch}-sbuild -d / -- dpkg --add-architecture arm64
    # Update /etc/apt/sources.list for cross-compilation  (Debian)
    cat <<__END__ | schroot -c source:${dist}-${arch}-sbuild -d / -- tee /etc/apt/sources.list
deb [arch=amd64,i386,armhf,arm64] http://deb.debian.org/debian ${dist} main contrib non-free non-free-firmware
deb [arch=amd64,i386,armhf,arm64] http://deb.debian.org/debian ${dist}-updates main contrib non-free non-free-firmware
deb [arch=amd64,i386,armhf,arm64] http://deb.debian.org/debian-security ${dist}-security main contrib non-free non-free-firmware
__END__
fi

# Install native build tools in the chroot
schroot -c source:${dist}-${arch}-sbuild -d / -- apt-get update
schroot -c source:${dist}-${arch}-sbuild -d / -- apt-get install -y build-essential python3 python3-pip python3-venv python3-dev g++ clang

# Install latest CMake version for Jammy and Bullseye
if [ "$dist" = "jammy" ] || [ "$dist" = "bullseye" ]; then
    schroot -c source:${dist}-${arch}-sbuild -d / -- bash -c "apt install -y python3-pip && \
        python3 -m pip install --upgrade pip && \
        python3 -m pip install cmake==3.31.6 && \
        ln -sf /usr/local/bin/cmake /usr/bin/cmake && \
        cmake --version"
fi


# Install Rust (pinned version via standalone installer) inside the sbuild chroot
schroot -c source:${dist}-${arch}-sbuild -d / -- bash -euxc '
  apt-get update && apt-get install -y --no-install-recommends wget xz-utils ca-certificates
  RUST_VERSION=1.88.0
  ARCH="$(uname -m)"
  if ldd --version 2>&1 | grep -q musl; then LIBC_TYPE="musl"; else LIBC_TYPE="gnu"; fi
  echo "Detected architecture: ${ARCH} and libc: ${LIBC_TYPE}"
  case "${ARCH}" in
    x86_64)
      if [ "${LIBC_TYPE}" = "musl" ]; then
        RUST_INSTALLER="rust-${RUST_VERSION}-x86_64-unknown-linux-musl"
        RUST_SHA256="200bcf3b5d574caededba78c9ea9d27e7afc5c6df4154ed0551879859be328e1"
      else
        RUST_INSTALLER="rust-${RUST_VERSION}-x86_64-unknown-linux-gnu"
        RUST_SHA256="7b5437c1d18a174faae253a18eac22c32288dccfc09ff78d5ee99b7467e21bca"
      fi
      ;;
    aarch64)
      if [ "${LIBC_TYPE}" = "musl" ]; then
        RUST_INSTALLER="rust-${RUST_VERSION}-aarch64-unknown-linux-musl"
        RUST_SHA256="f8b3a158f9e5e8cc82e4d92500dd2738ac7d8b5e66e0f18330408856235dec35"
      else
        RUST_INSTALLER="rust-${RUST_VERSION}-aarch64-unknown-linux-gnu"
        RUST_SHA256="d5decc46123eb888f809f2ee3b118d13586a37ffad38afaefe56aa7139481d34"
      fi
      ;;
    *) echo >&2 "Unsupported architecture: '${ARCH}'"; exit 1 ;;
  esac
  echo "Downloading and installing Rust standalone installer: ${RUST_INSTALLER}"
  wget --quiet -O ${RUST_INSTALLER}.tar.xz https://static.rust-lang.org/dist/${RUST_INSTALLER}.tar.xz
  echo "${RUST_SHA256} ${RUST_INSTALLER}.tar.xz" | sha256sum -c --quiet || { echo "Rust standalone installer checksum failed!"; exit 1; }
  tar -xf ${RUST_INSTALLER}.tar.xz
  (cd ${RUST_INSTALLER} && ./install.sh)
  rm -rf ${RUST_INSTALLER} ${RUST_INSTALLER}.tar.xz
'


# Prepare Boost 1.88.0 source inside the sbuild chroot (headers/libs layout, no build)
schroot -c source:${dist}-${arch}-sbuild -d / -- bash -euxc '
  apt-get update && apt-get install -y --no-install-recommends wget ca-certificates tar
  VERSION=1.88.0
  BOOST_NAME="boost_1_88_0"
  install -d /opt/boost
  cd /opt/boost
  echo "Downloading Boost ${VERSION} source archive..."
  wget -q https://github.com/boostorg/boost/releases/download/boost-${VERSION}/boost-${VERSION}-b2-nodocs.tar.gz -O ${BOOST_NAME}.tar.gz
  tar -xzf ${BOOST_NAME}.tar.gz
  mv boost-${VERSION} ${BOOST_NAME}
  rm -f ${BOOST_NAME}.tar.gz
'


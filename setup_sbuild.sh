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

# Create the sbuild chroot with the configuration (use directory chroot so installed tools persist into build clones)
sbuild-createchroot --arch=${arch} ${dist} /var/lib/sbuild/chroots/${dist}-${arch} ${url}

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
schroot -c source:${dist}-${arch}-sbuild -d / -- apt-get install -y build-essential python3 python3-pip python3-venv python3-dev g++ clang curl

# Install Astral uv inside chroot for RediSearch test dependencies that expect it
schroot -c source:${dist}-${arch}-sbuild -d / -- bash -lc "set -e; curl --proto '=https' --tlsv1.2 -LsSf https://astral.sh/uv/install.sh | sh"
# Make uv available system-wide in chroot PATH
schroot -c source:${dist}-${arch}-sbuild -d / -- bash -lc "install -m 0755 \"$HOME/.local/bin/uv\" /usr/local/bin/uv || cp -f \"$HOME/.local/bin/uv\" /usr/local/bin/uv"
# Verify uv installed and ensure it's in PATH via /usr/bin
schroot -c source:${dist}-${arch}-sbuild -d / -- bash -lc "ln -sf /usr/local/bin/uv /usr/bin/uv && /usr/bin/uv -V"

# Install latest CMake version for Jammy and Bullseye
if [ "$dist" = "jammy" ] || [ "$dist" = "bullseye" ]; then
    schroot -c source:${dist}-${arch}-sbuild -d / -- bash -c "apt install -y python3-pip && \
        python3 -m pip install --upgrade pip && \
        python3 -m pip install cmake==3.31.6 && \
        ln -sf /usr/local/bin/cmake /usr/bin/cmake && \
        cmake --version"
fi

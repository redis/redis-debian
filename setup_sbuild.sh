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

if [ "$dist" = "focal" ]; then
     ubuntu_ports="/ubuntu-ports"
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
    
    # Create a custom dpkg configuration for cross-compilation
    cat <<__END__ | schroot -c source:${dist}-${arch}-sbuild -d / -- tee /etc/dpkg/dpkg.cfg.d/cross-compile
# Don't install recommended packages automatically for cross-compilation
no-install-recommends
__END__
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

if [ "$dist" = "focal" ]; then
    # Install gcc-10 and g++-10 which are required in case of Ubuntu Focal to support Ranges library, introduced in C++20
    schroot -c source:${dist}-${arch}-sbuild -d / -- bash -c "apt update && apt remove -y gcc-9 g++-9 gcc-9-base && apt upgrade -yqq && apt install -y gcc build-essential gcc-10 g++-10 clang-format clang lcov openssl"
    schroot -c source:${dist}-${arch}-sbuild -d / -- bash -c "[ -f /usr/bin/gcc-10 ] && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 60 --slave /usr/bin/g++ g++ /usr/bin/g++-10|| echo 'gcc-10 installation failed'"
    
    # Install latest CMake version using pip for amd64 and arm64 architectures
    schroot -c source:${dist}-${arch}-sbuild -d / -- bash -c "apt install -y python3-pip && \
        pip3 install cmake==3.31.6 && \
        ln -sf /usr/local/bin/cmake /usr/bin/cmake && \
        cmake --version"

    # Install newer version of debhelper
    # Required because of a bug: https://bugs-devel.debian.org/cgi-bin/bugreport.cgi?bug=959731
    INSTALL_DEBHELPER_FROM_BULLSEYE="apt install -y wget \
      && wget http://ftp.de.debian.org/debian/pool/main/d/debhelper/libdebhelper-perl_13.3.4_all.deb \
              http://ftp.de.debian.org/debian/pool/main/d/debhelper/debhelper_13.3.4_all.deb \
      && dpkg -i libdebhelper-perl_13.3.4_all.deb debhelper_13.3.4_all.deb \
      || apt-get -yf install"
    schroot -c source:${dist}-${arch}-sbuild -d / -- bash -c "$INSTALL_DEBHELPER_FROM_BULLSEYE"
fi

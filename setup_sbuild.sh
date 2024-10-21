#!/bin/bash
if [ $# != 2 ]; then
    echo "Please use: setup_build.sh [dist] [arch]"
    exit 1
fi

dist="$1"
arch="$2"
if ubuntu-distro-info --all | grep -Fqx "$dist"; then
    disttype="ubuntu"
else
    disttype="debian"
fi

# Determine base apt repository URL based on type of distribution and architecture.
case "$disttype" in
    ubuntu)
        if [ "$arch" = "arm64" ]; then
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

sbuild-createchroot \
    --arch ${arch} --make-sbuild-tarball=/var/lib/sbuild/${dist}-${arch}.tar.gz \
    ${dist} `mktemp -d` ${url}

# Ubuntu has the main and ports repositories on different URLs, so we need to
# properly set up /etc/apt/sources.list to make cross compilation work
# and enable multi-architecture support inside a chroot environment
if [ "$disttype" = "ubuntu" ]; then
    schroot -c source:${dist}-${arch}-sbuild -d / -- dpkg --add-architecture i386
    schroot -c source:${dist}-${arch}-sbuild -d / -- dpkg --add-architecture armhf
    schroot -c source:${dist}-${arch}-sbuild -d / -- dpkg --add-architecture arm64
    # Update /etc/apt/sources.list for cross-compilation (Ubuntu)
    cat <<__END__ | schroot -c source:${dist}-${arch}-sbuild -d / -- tee /etc/apt/sources.list
deb [arch=amd64,i386] http://archive.ubuntu.com/ubuntu ${dist} main universe
deb [arch=amd64,i386] http://archive.ubuntu.com/ubuntu ${dist}-updates main universe
deb [arch=armhf,arm64] http://ports.ubuntu.com ${dist} main universe
deb [arch=armhf,arm64] http://ports.ubuntu.com ${dist}-updates main universe
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

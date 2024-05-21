#!/bin/bash
if [ $# != 1 ]; then
    echo "usage: release.sh [version]"
    exit 1
fi

set -e
VERSION="$1"

LATEST_VERSION=$(head -1 debian/changelog | sed 's/^.*([0-9]*:\([0-9\.]*\)-.*$/\1/')
if [ "$LATEST_VERSION" = "$VERSION" ]; then
    echo "To re-package the last release, please manually update debian/changelog."
    exit 1
fi

AUTHOR=$(grep -m 1 '^ --' debian/changelog | sed 's/^ -- \(.*>\)  *.*$/\1/')

sed -i "1i \
redis (6:$VERSION-1rl1~@RELEASE@1) @RELEASE@; urgency=low\n\
\n\
  * Redis $VERSION: https://github.com/redis/redis/releases/tag/$VERSION\n\
\n\
 -- $AUTHOR $(date -R)\n" debian/changelog

git add debian/changelog
git commit -m "Redis $VERSION"

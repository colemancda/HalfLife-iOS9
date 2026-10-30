#!/bin/bash
# Assembles build/xash3d.app from the engine, SDL2 and HLSDK builds, signs it,
# and with "install" copies it to /Applications on a jailbroken device.
#
#   ./package.sh            build/xash3d.app
#   ./package.sh install    also install over SSH
#
# install uses ssh to $SSH_HOST (default iphone), with the config file in
# $SSH_CONF if set, e.g. a host entry for a USB tunnel from `iproxy 2222:22`.
set -euo pipefail
cd "$(dirname "$0")"
TOP=$PWD
APP=build/xash3d.app
SSH_HOST=${SSH_HOST:-iphone}

rm -rf "$APP" && mkdir -p "$APP"

# Engine, filesystem, menu and renderers go in the bundle root.
(cd xash3d-fwgs && IOS_SDK=$TOP/sdk/iPhoneOS9.3.sdk IOS_ARCH=armv7 IOS_MIN_VERSION=9.0 \
  ./waf install -o "$TOP/build/xash3d-armv7" --destdir="$TOP/$APP")

# Game libraries: valve/dlls and valve/cl_dlls, read from the bundle.
cmake --install build/hlsdk-armv7 --prefix "$TOP/$APP"

cp -R build/SDL2.framework "$APP/"
plutil -convert binary1 -o "$APP/Info.plist" bundle/Info.plist
printf 'APPL????' > "$APP/PkgInfo"

# Home screen icons, made from your own Steam install (not in the repo)
if [ -d bundle/icons ]; then
  cp bundle/icons/*.png "$APP/"
fi

# Ad-hoc sign every Mach-O; iOS 9 kills unsigned code even when jailbroken.
find "$APP" -type f \( -name '*.dylib' -o -name xash -o -path '*/SDL2.framework/SDL2' \) -print0 |
  xargs -0 -n1 ldid -S

echo "Built $APP"

if [ "${1:-}" = install ]; then
  COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -C build -cf - xash3d.app |
    ssh ${SSH_CONF:+-F "$SSH_CONF"} "$SSH_HOST" 'cd /&& rm -rf /Applications/xash3d.app && tar -C /Applications -xf - && chown -R root:wheel /Applications/xash3d.app && su mobile -c uicache'
  echo "Installed to /Applications/xash3d.app"
fi

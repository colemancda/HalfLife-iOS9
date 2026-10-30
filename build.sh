#!/bin/bash
# Builds Half-Life (Xash3D FWGS + HLSDK) for armv7 / iOS 9, e.g. the iPhone 4S.
#
#   ./build.sh            build build/xash3d.app
#   ./build.sh install    also install it on a jailbroken device (see package.sh)
#
# Downloads are read from $DOWNLOADS (default ./downloads); see README.md.
set -euo pipefail
cd "$(dirname "$0")"
TOP=$PWD
SDK=$TOP/sdk/iPhoneOS9.3.sdk

[ -d "$SDK" ] || ./make-sdk.sh

git submodule update --init --recursive

# Applies a patch unless it already is.
apply_patch() {
  local dir=$1 patch=$TOP/patches/$2
  if git -C "$dir" apply --reverse --check "$patch" 2>/dev/null; then
    echo "Already applied: $2"
  else
    git -C "$dir" apply "$patch"
  fi
}
apply_patch xash3d-fwgs xash3d-fwgs-ios9-armv7.patch
apply_patch xash3d-fwgs/3rdparty/mbedtls/mbedtls tf-psa-crypto-no-clock_gettime.patch
apply_patch hlsdk-portable/freevgui freevgui-no-clock_gettime.patch

[ -d build/SDL2.framework ] || ./build-sdl2.sh

# Engine, menu, filesystem and renderers. NanoGL (gles1) is the default
# renderer on iOS; the A5's GPU only has OpenGL ES 2.0.
export IOS_SDK=$SDK IOS_ARCH=armv7 IOS_MIN_VERSION=9.0
(cd xash3d-fwgs &&
  ./waf configure --ios --enable-bundled-deps --sdl2="$TOP/build/SDL2.framework" -o "$TOP/build/xash3d-armv7" &&
  ./waf build -o "$TOP/build/xash3d-armv7")

# Half-Life game libraries (hl_ios_armv7l.dylib, client_ios_armv7l.dylib).
cmake -S hlsdk-portable -B build/hlsdk-armv7 -G Ninja \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$SDK" \
  -DCMAKE_OSX_ARCHITECTURES=armv7 -DCMAKE_OSX_DEPLOYMENT_TARGET=9.0 \
  -DCMAKE_C_FLAGS=-marm -DCMAKE_CXX_FLAGS=-marm -DCMAKE_BUILD_TYPE=Release
cmake --build build/hlsdk-armv7

./package.sh "$@"

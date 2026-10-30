#!/bin/bash
# Builds SDL2.framework for armv7 / iOS 9 from the SDL release tarball,
# downloading it into $DOWNLOADS (default ./downloads) if it's missing.
set -euo pipefail
VERSION=2.32.10
SHA256=5f5993c530f084535c65a6879e9b26ad441169b3e25d789d83287040a9ca5165
cd "$(dirname "$0")"
TOP=$PWD
ARCHIVE=${1:-${DOWNLOADS:-downloads}/SDL2-$VERSION.tar.gz}
if [ ! -f "$ARCHIVE" ]; then
  mkdir -p "$(dirname "$ARCHIVE")"
  curl -fL -o "$ARCHIVE.tmp" "https://github.com/libsdl-org/SDL/releases/download/release-$VERSION/SDL2-$VERSION.tar.gz"
  mv "$ARCHIVE.tmp" "$ARCHIVE"
fi
echo "$SHA256  $ARCHIVE" | shasum -a 256 -c -
SDK=$TOP/sdk/iPhoneOS9.3.sdk
SRC=src/SDL2-$VERSION
BUILD=build/sdl2-armv7
FW=build/SDL2.framework
[ -d "$SDK" ] || ./make-sdk.sh

# Fresh, patched sources: SDL 2.32 targets iOS 9 at runtime but uses
# declarations from newer SDKs, which the patch guards.
rm -rf "$SRC" && mkdir -p src
tar -xzf "$ARCHIVE" -C src
patch -d src -p1 < patches/SDL2-$VERSION-ios9-sdk.patch

# Metal and HIDAPI aren't useful on an A5. -marm: see make-sdk.sh notes.
cmake -S "$SRC" -B "$BUILD" -G Ninja \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$SDK" \
  -DCMAKE_OSX_ARCHITECTURES=armv7 -DCMAKE_OSX_DEPLOYMENT_TARGET=9.0 \
  -DCMAKE_C_FLAGS=-marm -DCMAKE_OBJC_FLAGS=-marm -DCMAKE_BUILD_TYPE=Release \
  -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF \
  -DSDL_METAL=OFF -DSDL_RENDER_METAL=OFF -DSDL_HIDAPI=OFF
cmake --build "$BUILD"

# Same layout as SDL's Xcode-built framework, which waf and createipa.sh expect.
rm -rf "$FW" && mkdir -p "$FW/Headers"
cp "$BUILD/libSDL2-2.0.0.dylib" "$FW/SDL2"
install_name_tool -id @rpath/SDL2.framework/SDL2 "$FW/SDL2"
cp "$SRC"/include/*.h "$FW/Headers/"
cp "$BUILD"/include-config-release/SDL2/SDL_config.h "$FW/Headers/"
cat > "$FW/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>SDL2</string>
	<key>CFBundleIdentifier</key>
	<string>org.libsdl.SDL2</string>
	<key>CFBundlePackageType</key>
	<string>FMWK</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>MinimumOSVersion</key>
	<string>9.0</string>
</dict>
</plist>
PLIST
ldid -S "$FW/SDL2"
echo "Built $FW"

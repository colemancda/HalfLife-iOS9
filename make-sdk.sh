#!/bin/bash
# Unpacks theos' iPhoneOS9.3.sdk and fixes its .tbd stubs for Xcode's linker.
#
#   ./make-sdk.sh [path/to/iPhoneOS9.3.sdk.tar.xz]
#
# The archive defaults to $DOWNLOADS (default ./downloads). Get it from
# https://github.com/theos/sdks/releases (iPhoneOS9.3.sdk.tar.xz).
set -euo pipefail
cd "$(dirname "$0")"
ARCHIVE=${1:-${DOWNLOADS:-downloads}/iPhoneOS9.3.sdk.tar.xz}
if [ ! -f "$ARCHIVE" ]; then
  echo "Missing $ARCHIVE: download iPhoneOS9.3.sdk.tar.xz from https://github.com/theos/sdks/releases" >&2
  exit 1
fi
SDK=sdk/iPhoneOS9.3.sdk
rm -rf sdk && mkdir sdk
tar -xJf "$ARCHIVE" -C sdk

# Simulator architectures make Xcode's linker treat the stubs as simulator-only.
find "$SDK" -name '*.tbd' -type f -print0 | xargs -0 sed -i '' -E \
  's/(archs: *\[ armv7, armv7s, arm64), i386, x86_64 \]/\1 ]/'

# libSystem functions the stubs leave out.
perl -0pi -e 's/(symbols: *\[ )/$1_bzero, _memchr, _memcmp, _memcpy, _memmove, _memset, _memset_pattern4, _memset_pattern8, _memset_pattern16, _strchr, _strcmp, _strncmp, /' \
  "$SDK/usr/lib/system/libsystem_platform.tbd"

# Weakly referenced by compiler-rt's @available support (iOS 15+ libSystem);
# missing at runtime on iOS 9, where compiler-rt falls back to SystemVersion.plist.
perl -0pi -e 's/(symbols: *\[ )/$1__availability_version_check, /' \
  "$SDK/usr/lib/system/libdyld.tbd"

# The real libc++.1.dylib re-exports libc++abi (operator new, RTTI vtables).
perl -0pi -e 's/(\nexports:\n  - archs: *\[[^\]]*\]\n)/$1    re-exports:         [ \/usr\/lib\/libc++abi.dylib ]\n/' \
  "$SDK/usr/lib/libc++.1.tbd"
grep -q 're-exports:' "$SDK/usr/lib/libc++.1.tbd"
# The SDK has no libc++ headers; use the current Xcode SDK's, which honour
# -mios-version-min. Link errors against the 9.3 stubs catch anything newer.
XCODE_SDK=$(xcrun --show-sdk-path --sdk iphoneos)
mkdir -p "$SDK/usr/include/c++"
cp -R "$XCODE_SDK/usr/include/c++/v1" "$SDK/usr/include/c++/v1"

echo "SDK ready: $SDK"

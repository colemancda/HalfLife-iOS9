# HalfLife-iOS9

Builds Half-Life for 32-bit iOS 9 devices (iPhone 4S, armv7) with
[Xash3D FWGS](https://github.com/FWGS/xash3d-fwgs) and
[hlsdk-portable](https://github.com/FWGS/hlsdk-portable), using a current Xcode.

Upstream's iOS port targets arm64 and iOS 12. This repo pins both projects as
submodules and adds the build scripts and patches to target armv7 with the
iOS 9.3 SDK. Tested on an iPhone 4S running iOS 9.3.6: the game runs with the
NanoGL (`gles1`) renderer at 960×640, with touch controls.

Game data isn't included. You need your own copy of Half-Life (Steam).

## Requirements

- Xcode (tested with 27.1), for `clang`, the linker and `plutil`.
- [CMake](https://cmake.org) and [Ninja](https://ninja-build.org): `brew install cmake ninja`.
- [`ldid`](https://formulae.brew.sh/formula/ldid) for signing: `brew install ldid`.
- `iPhoneOS9.3.sdk.tar.xz` from [theos/sdks](https://github.com/theos/sdks/releases),
  in `downloads/` or the folder in `$DOWNLOADS`. The SDL2 source tarball is
  downloaded there automatically.
- To install: a jailbroken device with OpenSSH.

## Building

```bash
git clone --recursive git@github.com:colemancda/HalfLife-iOS9.git
cd HalfLife-iOS9
./build.sh
```

This produces `build/xash3d.app`:

| Step | Script |
|---|---|
| Unpack and fix the iOS 9.3 SDK | `make-sdk.sh` |
| Build `SDL2.framework` (SDL 2.32.10) | `build-sdl2.sh` |
| Apply `patches/`, build the engine (waf) and game libraries (CMake) | `build.sh` |
| Assemble and sign the app, optionally install it | `package.sh` |

## Installing

`./build.sh install` (or `./package.sh install`) copies the app to
`/Applications` over SSH, where a jailbroken device runs it without AppSync,
and refreshes the home screen. It connects to `$SSH_HOST` (default `iphone`),
with `$SSH_CONF` as the SSH config file if set. Over USB, run
`iproxy 2222:22` from libimobiledevice and add a host entry for `localhost`
port 2222.

Then copy Half-Life's `valve` folder from your Steam install to
`/var/mobile/Documents/valve` on the device. To save space you can leave out
`dlls`, `cl_dlls` (Windows libraries), `overviews` (multiplayer maps),
`media` (soundtrack) and `SAVE`: about 420 MB instead of 520 MB.

Launch it from the home screen, or over SSH with `uiopen xash3d://`. The
engine log is `/var/mobile/Documents/engine.log`.

## Patches

| Patch | Why |
|---|---|
| `xash3d-fwgs-ios9-armv7.patch` | Makes the iOS target's architecture, SDK and minimum version configurable (`IOS_ARCH`, `IOS_SDK`, `IOS_MIN_VERSION`); guards the iOS 11 safe-area code; disables libbacktrace when `_Unwind_Backtrace` is missing (armv7 iOS only has SjLj unwinding). |
| `tf-psa-crypto-no-clock_gettime.patch` | mbedtls: `gettimeofday` fallback, since `clock_gettime` is iOS 10+. |
| `freevgui-no-clock_gettime.patch` | Same, for hlsdk-portable's freevgui. |
| `SDL2-2.32.10-ios9-sdk.patch` | SDL still supports iOS 9 at runtime, but uses declarations that are only in newer SDKs. Guards them by SDK version. |

`make-sdk.sh` also fixes the SDK's `.tbd` stubs for Xcode's linker: it
removes the simulator architectures, adds missing libSystem functions
(`memcpy`, `strchr`, `memset_pattern16` and others), adds `libc++`'s
re-export of `libc++abi`, and copies in libc++ headers from Xcode's current
iOS SDK.

## Toolchain notes

- Everything is built as ARM (`-marm`), not Thumb: Xcode's linker writes an
  even `LC_MAIN` entry offset for a Thumb `main()`, which crashes at launch.
- The linker warns about `liblaunch.dylib` missing from the SDK stubs. That's
  harmless.

## Known issues

- With no game data on the device, the engine shows its error and then
  crashes on exit.

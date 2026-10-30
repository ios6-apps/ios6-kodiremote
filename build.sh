#!/bin/bash
# build.sh device  -> build/KodiRemote.ipa (armv7, iOS 6, unsigned; install with ideviceinstaller on an AppSync device)
# build.sh sim     -> build/sim/KodiRemote.app (arm64 simulator, for previewing the layout with live data)
# SDK93 must point at an iOS 9.3 SDK (stub frameworks are enough, we link with -undefined dynamic_lookup).
set -e
cd "$(dirname "$0")"
SRC=(src/*.m)
if [ "$1" = device ]; then
    : "${SDK93:?set SDK93 to the iOS 9.3 SDK path}"
    rm -rf build/device; mkdir -p build/device/Payload/KodiRemote.app
    # compile with ARC but link without it: the Xcode toolchain has no libarclite, and iOS 6's libobjc already has the ARC entry points we use
    OBJS=()
    for f in "${SRC[@]}"; do
        o=build/device/$(basename "$f" .m).o
        xcrun clang -arch armv7 -miphoneos-version-min=6.0 -isysroot "$SDK93" -fobjc-arc -Os -Wno-deprecated-declarations -c "$f" -o "$o"
        OBJS+=("$o")
    done
    xcrun clang -arch armv7 -miphoneos-version-min=6.0 -isysroot "$SDK93" \
        -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework AudioToolbox -undefined dynamic_lookup \
        "${OBJS[@]}" -o build/device/Payload/KodiRemote.app/KodiRemote
    cp Info.plist res/*.png build/device/Payload/KodiRemote.app/
    (cd build/device && zip -q -r ../KodiRemote.ipa Payload)
    echo "built build/KodiRemote.ipa"
else
    SIM=$(xcrun --sdk iphonesimulator --show-sdk-path)
    rm -rf build/sim; mkdir -p build/sim/KodiRemote.app
    xcrun clang -arch arm64 -mios-simulator-version-min=15.0 -isysroot "$SIM" -fobjc-arc -O0 -DKR_PREVIEW -Wno-deprecated-declarations \
        -framework UIKit -framework Foundation -framework CoreGraphics -framework QuartzCore -framework AudioToolbox \
        "${SRC[@]}" -o build/sim/KodiRemote.app/KodiRemote
    cp Info.plist res/*.png build/sim/KodiRemote.app/
    echo "built build/sim/KodiRemote.app"
fi

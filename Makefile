# ClipMan — clipboard manager.
#
# Release pipeline delegated to the shared `release.mk` from
# PerpetualBeta/jorvik-release. ClipMan is an SPM project with
# embedded Sparkle and dual-ship (.zip + .pkg).

BUNDLE_NAME      := ClipMan
BUNDLE_TYPE      := app
PRODUCT_NAME     := ClipMan.app
BUNDLE_ID        := com.jorviksoftware.clipman
BUILD_SYSTEM     := spm
SPM_PRODUCT      := ClipMan

PACKAGE_TYPE     := zip
ALSO_SHIP_PKG    := true
EMBEDDED_FRAMEWORKS := Sparkle
ENTITLEMENTS     := ClipMan.entitlements

# ClipMan keeps both Info.plist and the icon under Resources/.
INFO_PLIST       := Resources/Info.plist
ICON_FILE        := ClipMan.icns

include ../jorvik-release/release.mk

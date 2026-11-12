#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

PROJECT="${PROJECT:-AlterEgo.xcodeproj}"
SCHEME="${SCHEME:-AlterEgo}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-$ROOT/build}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"

IOS_DIR="$BUILD_DIR/ios"
MACOS_DIR="$BUILD_DIR/macos"
IOS_ARCHIVE="$IOS_DIR/AlterEgo.xcarchive"
MACOS_ARCHIVE="$MACOS_DIR/AlterEgo.xcarchive"
IOS_IPA="$IOS_DIR/AlterEgo.ipa"
MACOS_APP="$MACOS_DIR/AlterEgo.app"
MACOS_ZIP="$MACOS_DIR/AlterEgo.zip"

BUILD_IOS=1
BUILD_MACOS=1

usage() {
    cat <<'EOF'
Usage: ./Build Apps.sh [options]

Builds the AlterEgo iOS IPA and macOS app.

Options:
  --ios                 Build only the iOS IPA
  --macos               Build only the macOS app
  --debug               Use the Debug configuration
  --release             Use the Release configuration (default)
  --clean               Remove previous archives and output before building
  -h, --help            Show this help

Environment:
  PROJECT                       Xcode project path (default: AlterEgo.xcodeproj)
  SCHEME                        Scheme to build (default: AlterEgo)
  CONFIGURATION                 Build configuration (default: Release)
  BUILD_DIR                     Output directory (default: ./build)
  ALLOW_PROVISIONING_UPDATES    Set to 0 to disable -allowProvisioningUpdates
  CODE_SIGNING_ALLOWED          Override code signing (e.g. NO for an unsigned build)

Outputs:
  build/ios/AlterEgo.ipa
  build/macos/AlterEgo.app
  build/macos/AlterEgo.zip
EOF
}

CLEAN=0

if [[ $# -gt 0 ]]; then
    BUILD_IOS=0
    BUILD_MACOS=0

    for arg in "$@"; do
        case "$arg" in
            --ios)
                BUILD_IOS=1
                ;;
            --macos)
                BUILD_MACOS=1
                ;;
            --debug)
                CONFIGURATION="Debug"
                ;;
            --release)
                CONFIGURATION="Release"
                ;;
            --clean)
                CLEAN=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $arg" >&2
                usage >&2
                exit 1
                ;;
        esac
    done
fi

SIGNING_ARGS=""
if [[ "$ALLOW_PROVISIONING_UPDATES" != "0" ]]; then
    SIGNING_ARGS="$SIGNING_ARGS -allowProvisioningUpdates"
fi
if [[ -n "${CODE_SIGNING_ALLOWED:-}" ]]; then
    SIGNING_ARGS="$SIGNING_ARGS CODE_SIGNING_ALLOWED=$CODE_SIGNING_ALLOWED"
fi

if [[ "$CLEAN" == "1" ]]; then
    echo "Cleaning previous build output..."
    rm -rf "$IOS_DIR" "$MACOS_DIR"
fi

mkdir -p "$IOS_DIR" "$MACOS_DIR"

archive_ios() {
    echo "Archiving iOS app..."
    rm -rf "$IOS_ARCHIVE"

    /usr/bin/xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=iOS" \
        -archivePath "$IOS_ARCHIVE" \
        $SIGNING_ARGS

    local app_path
    app_path="$(find "$IOS_ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' -print -quit)"
    if [[ -z "$app_path" ]]; then
        echo "Could not find the archived iOS app." >&2
        exit 1
    fi

    echo "Packaging iOS IPA..."
    rm -rf "$IOS_DIR/Payload"
    mkdir -p "$IOS_DIR/Payload"
    /usr/bin/ditto "$app_path" "$IOS_DIR/Payload/$(basename "$app_path")"
    rm -f "$IOS_IPA"
    (cd "$IOS_DIR" && /usr/bin/zip -qry "$(basename "$IOS_IPA")" Payload)

    echo "Built $IOS_IPA"
}

archive_macos() {
    echo "Archiving macOS app..."
    rm -rf "$MACOS_ARCHIVE"

    /usr/bin/xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -destination "generic/platform=macOS" \
        -archivePath "$MACOS_ARCHIVE" \
        $SIGNING_ARGS

    local app_path
    app_path="$(find "$MACOS_ARCHIVE/Products/Applications" -maxdepth 1 -name '*.app' -print -quit)"
    if [[ -z "$app_path" ]]; then
        echo "Could not find the archived macOS app." >&2
        exit 1
    fi

    echo "Packaging macOS app..."
    rm -rf "$MACOS_APP" "$MACOS_ZIP"
    /usr/bin/ditto "$app_path" "$MACOS_APP"
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$MACOS_APP" "$MACOS_ZIP"

    echo "Built $MACOS_APP"
    echo "Built $MACOS_ZIP"
}

if [[ "$BUILD_IOS" == "1" ]]; then
    archive_ios
fi

if [[ "$BUILD_MACOS" == "1" ]]; then
    archive_macos
fi

echo "Done."

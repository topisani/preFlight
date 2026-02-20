#!/usr/bin/env bash
#/|/ Copyright (c) preFlight 2025+ oozeBot, LLC
#/|/
#/|/ Released under AGPLv3 or higher
#/|/
# Builds preFlight application for macOS using Ninja.
# Prerequisites: Run ./build_deps.sh -preset mac_universal_arm first (Apple Silicon)
#                or ./build_deps.sh -preset mac_universal_x86 (Intel Mac)
#
# Usage: ./build_macos.sh [options]
#   -debug    Build RelWithDebInfo instead of Release
#   -jobs N   Number of parallel build jobs (default: auto-detect)
#   -clean    Remove build directory and reconfigure from scratch
#   -config   Run cmake configure only, don't build
#   -arch A   Target architecture: arm64 or x86_64 (default: auto-detect)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="Release"
BUILD_SUBDIR=""
JOBS=$(sysctl -n hw.ncpu)
CLEAN=0
CONFIG_ONLY=0
ARCH=$(uname -m)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -debug)   CONFIG="RelWithDebInfo"; BUILD_SUBDIR="_debug" ;;
        -jobs)    JOBS="$2"; shift ;;
        -clean)   CLEAN=1 ;;
        -config)  CONFIG_ONLY=1 ;;
        -arch)    ARCH="$2"; shift ;;
        -h|-help|--help)
            sed -n '10,16p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Validate architecture
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
    echo "ERROR: Unsupported architecture '$ARCH'. Use arm64 or x86_64."
    exit 1
fi

# Set deployment target based on architecture
# arm64 requires macOS 11.0+ (first Apple Silicon release)
# x86_64 can target macOS 10.13+ (matches Info.plist LSMinimumSystemVersion)
if [[ "$ARCH" == "arm64" ]]; then
    DEPLOY_TARGET="11.0"
else
    DEPLOY_TARGET="10.13"
fi

BUILD_DIR="$SCRIPT_DIR/build${BUILD_SUBDIR}"
DEPS_PATH_FILE="$SCRIPT_DIR/deps/build/.DEPS_PATH.txt"
START_TIME=$SECONDS

# Read deps path
if [[ ! -f "$DEPS_PATH_FILE" ]]; then
    echo "ERROR: Dependencies not built. Run ./build_deps.sh first."
    exit 1
fi
DESTDIR="$(cat "$DEPS_PATH_FILE")"

echo "**********************************************************************"
echo "** preFlight macOS Build (Ninja)"
echo "** Config:    $CONFIG"
echo "** Arch:      $ARCH"
echo "** Deploy:    macOS $DEPLOY_TARGET"
echo "** Build dir: $BUILD_DIR"
echo "** Deps:      $DESTDIR"
echo "** Jobs:      $JOBS"
echo "**********************************************************************"

# Clean if requested
if [[ $CLEAN -eq 1 && -d "$BUILD_DIR" ]]; then
    echo "** Cleaning $BUILD_DIR ..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Configure with Ninja
echo ""
echo "** Running CMake with Ninja generator ..."
cmake "$SCRIPT_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE="$CONFIG" \
    -DCMAKE_PREFIX_PATH="$DESTDIR" \
    -DSLIC3R_STATIC=1 \
    -DSLIC3R_PCH=1 \
    -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY_TARGET" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_CXX_FLAGS="-I/opt/homebrew/include"

if [[ $CONFIG_ONLY -eq 1 ]]; then
    echo ""
    echo "** Configuration complete. Skipping build (-config flag)."
    echo "** compile_commands.json: $BUILD_DIR/compile_commands.json"
    exit 0
fi

# Build
echo ""
echo "** Building with Ninja ($JOBS parallel jobs) ..."
ninja -j "$JOBS"

ELAPSED=$(( SECONDS - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
echo "**********************************************************************"
echo "** Build complete!"
echo "** Elapsed: ${MINS}m ${SECS}s"
echo "** compile_commands.json: $BUILD_DIR/compile_commands.json"
echo "** Executable: $BUILD_DIR/src/preFlight"
echo "**********************************************************************"

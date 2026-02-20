#!/usr/bin/env bash
#/|/ Copyright (c) preFlight 2025+ oozeBot, LLC
#/|/
#/|/ Released under AGPLv3 or higher
#/|/
# Builds preFlight dependencies.
# Usage: ./build_deps.sh [options]
#   -clean    Remove existing deps build and rebuild from scratch
#   -preset   CMake preset override (auto-detected if not specified)
#
# Platform auto-detection:
#   macOS arm64  → mac_universal_arm
#   macOS x86_64 → mac_universal_x86
#   Linux        → default
#
# Dependencies are installed to deps/build-<preset>/destdir/usr/local

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLEAN=0
PRESET=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -clean)  CLEAN=1 ;;
        -preset) PRESET="$2"; shift ;;
        -h|-help|--help)
            sed -n '5,16p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Auto-detect preset if not specified
if [[ -z "$PRESET" ]]; then
    if [[ "$(uname -s)" == "Darwin" ]]; then
        if [[ "$(uname -m)" == "arm64" ]]; then
            PRESET="mac_universal_arm"
        else
            PRESET="mac_universal_x86"
        fi
    else
        PRESET="default"
    fi
fi

DEPS_DIR="$SCRIPT_DIR/deps"
BUILD_DIR="$DEPS_DIR/build-${PRESET}"
DESTDIR="$BUILD_DIR/destdir/usr/local"
DEPS_PATH_FILE="$DEPS_DIR/build/.DEPS_PATH.txt"
START_TIME=$SECONDS

PLATFORM="$(uname -s)"
if [[ "$PLATFORM" == "Darwin" ]]; then
    PLATFORM="macOS ($(uname -m))"
fi

echo "**********************************************************************"
echo "** preFlight Dependency Build ($PLATFORM)"
echo "** Preset: $PRESET"
echo "** Output: $DESTDIR"
echo "**********************************************************************"

# Clean if requested
if [[ $CLEAN -eq 1 && -d "$BUILD_DIR" ]]; then
    echo "** Cleaning $BUILD_DIR ..."
    rm -rf "$BUILD_DIR"
fi

# Configure
echo ""
echo "** Configuring deps ..."
cd "$DEPS_DIR"
cmake --preset "$PRESET"

# Build - single-threaded top-level (each dep builds in parallel internally)
# -k flag tells make to continue past failures in independent targets
echo ""
echo "** Building deps (this will take a while) ..."
cmake --build "$BUILD_DIR" -j 1 -- -k

# Record deps path for the app build script
mkdir -p "$DEPS_DIR/build"
echo "$DESTDIR" > "$DEPS_PATH_FILE"

ELAPSED=$(( SECONDS - START_TIME ))
MINS=$(( ELAPSED / 60 ))
SECS=$(( ELAPSED % 60 ))

echo ""
echo "**********************************************************************"
echo "** Deps build complete!"
echo "** Elapsed: ${MINS}m ${SECS}s"
echo "** Installed to: $DESTDIR"
echo "**********************************************************************"

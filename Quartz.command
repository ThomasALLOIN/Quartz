#!/bin/zsh

set -e

PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"

if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/private/tmp}/quartz-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/private/tmp}/quartz-swiftpm-cache"

swift run quartz "$@"

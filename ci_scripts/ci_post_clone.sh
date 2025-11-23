#! /bin/sh
brew tap FelixHerrmann/tap
brew install swift-package-list

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_PATH="${SCRIPT_DIR}/../Config.secret.xcconfig"

set +x 2>/dev/null
printf "GOOGLE_MAPS_API_KEY = %s\n" "${GOOGLE_MAPS_API_KEY}" >> "${CONFIG_PATH}"
set -x 2>/dev/null

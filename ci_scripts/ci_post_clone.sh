#! /bin/sh
brew tap FelixHerrmann/tap
brew install swift-package-list

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SECRET_CONFIG_PATH="${SCRIPT_DIR}/../Config.secret.xcconfig"
VERSION_CONFIG_PATH="${SCRIPT_DIR}/../Config.version.xcconfig"

set +x 2>/dev/null
printf "GOOGLE_MAPS_API_KEY = %s\n" "${GOOGLE_MAPS_API_KEY}" >> "${SECRET_CONFIG_PATH}"
printf "MARKETING_VERSION = 1.%s\n" "${CI_PULL_REQUEST_NUMBER:-0}" >> "${VERSION_CONFIG_PATH}"
set -x 2>/dev/null

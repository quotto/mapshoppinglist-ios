#! /bin/sh
brew tap FelixHerrmann/tap
brew install swift-package-list

{ set +x; } 2>/dev/null
printf "GOOGLE_MAPS_API_KEY = %s\n" "${GOOGLE_MAPS_API_KEY}" >> ../Config.secret.xcconfig
{ set -x; } 2>/dev/null

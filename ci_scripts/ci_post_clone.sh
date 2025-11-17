#! /bin/sh
brew tap FelixHerrmann/tap
brew install swift-package-list

echo "GOOGLE_MAPS_API_KEY = ${GOOGLE_MAPS_API_KEY}" >> Config.secret.xcconfig

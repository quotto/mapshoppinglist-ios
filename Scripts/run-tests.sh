#!/bin/bash
set -euo pipefail

# CI/ローカル共通のテスト実行スクリプト
# - DESTINATION: 使用するシミュレータ指定（未指定時は iPhone 15 Pro Max / iOS 17.5）
# - SCHEME, PROJECT_PATH: テスト対象を切り替えたい場合に上書きする

DESTINATION=${DESTINATION:-"platform=iOS Simulator,name=iPhone 15 Pro Max,OS=17.5"}
SCHEME=${SCHEME:-"MapShoppingList"}
PROJECT_PATH=${PROJECT_PATH:-"MapShoppingList.xcodeproj"}

xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  clean test

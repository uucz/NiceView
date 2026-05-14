#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

IOS_BUNDLE_ID="${IOS_BUNDLE_ID:-com.ortlinde.niceview}"
IOS_ORG="${IOS_ORG:-com.ortlinde}"
IOS_PROJECT_NAME="${IOS_PROJECT_NAME:-nice_view}"
VERSION="${1:-}"
BUILD_VERSION="${2:-}"

PUBSPEC_VERSION="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1)"
if [ -z "$VERSION" ]; then
  VERSION="${PUBSPEC_VERSION%%+*}"
fi
if [ -z "$BUILD_VERSION" ]; then
  if [ "$PUBSPEC_VERSION" != "${PUBSPEC_VERSION#*+}" ]; then
    BUILD_VERSION="${PUBSPEC_VERSION#*+}"
  else
    BUILD_VERSION="1"
  fi
fi

if [ -z "$VERSION" ] || [ -z "$BUILD_VERSION" ]; then
  echo "无法解析 iOS 构建版本，请传入 version 和 buildVersion。" >&2
  exit 1
fi

flutter create --platforms=ios --org "$IOS_ORG" --project-name "$IOS_PROJECT_NAME" .

IOS_BUNDLE_ID="$IOS_BUNDLE_ID" /usr/bin/perl -0pi -e \
  's/PRODUCT_BUNDLE_IDENTIFIER = [^;]+;/PRODUCT_BUNDLE_IDENTIFIER = $ENV{IOS_BUNDLE_ID};/g' \
  ios/Runner.xcodeproj/project.pbxproj

if /usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" ios/Runner/Info.plist >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Nice View" ios/Runner/Info.plist
else
  /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Nice View" ios/Runner/Info.plist
fi

flutter pub get
flutter build ios --release --no-codesign --build-name "$VERSION" --build-number "$BUILD_VERSION"

APP_PATH="build/ios/iphoneos/Runner.app"
IPA_ROOT="build/ios/unsigned_ipa"
IPA_PATH="build/ios/niceview-unsigned.ipa"

if [ ! -d "$APP_PATH" ]; then
  echo "未找到 iOS App 产物：$APP_PATH" >&2
  exit 1
fi

rm -rf "$IPA_ROOT" "$IPA_PATH"
mkdir -p "$IPA_ROOT/Payload"
cp -R "$APP_PATH" "$IPA_ROOT/Payload/Runner.app"

(
  cd "$IPA_ROOT"
  /usr/bin/zip -qry "../niceview-unsigned.ipa" Payload
)

echo "$IPA_PATH"

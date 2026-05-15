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

set_plist_string() {
  local key="$1"
  local value="$2"
  local plist="ios/Runner/Info.plist"

  if /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :$key $value" "$plist"
  else
    /usr/libexec/PlistBuddy -c "Add :$key string $value" "$plist"
  fi
}

IOS_BUNDLE_ID="$IOS_BUNDLE_ID" /usr/bin/perl -0pi -e \
  's/PRODUCT_BUNDLE_IDENTIFIER = [^;]+;/PRODUCT_BUNDLE_IDENTIFIER = $ENV{IOS_BUNDLE_ID};/g' \
  ios/Runner.xcodeproj/project.pbxproj

set_plist_string "CFBundleDisplayName" "Nice View"
set_plist_string "NSPhotoLibraryAddUsageDescription" "Nice View 需要将图片保存到系统相册。"
set_plist_string "NSPhotoLibraryUsageDescription" "Nice View 需要将图片保存到系统相册。"
set_plist_string "UILaunchStoryboardName" "LaunchScreen"

cp scripts/templates/ios/AppDelegate.swift ios/Runner/AppDelegate.swift
mkdir -p ios/Runner/Base.lproj
cp scripts/templates/ios/LaunchScreen.storyboard ios/Runner/Base.lproj/LaunchScreen.storyboard

python3 - ios/Runner/Assets.xcassets/AppIcon.appiconset <<'PY'
from __future__ import annotations

import json
import math
import struct
import sys
import zlib
from pathlib import Path


def chunk(kind: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    )


def write_png(path: Path, size: int) -> None:
    rows = []
    center = (size - 1) / 2
    radius = size * 0.36
    stroke = max(2, size // 18)
    for y in range(size):
        row = bytearray()
        row.append(0)
        for x in range(size):
            dx = x - center
            dy = y - center
            distance = math.hypot(dx, dy)
            amber = distance < radius
            diagonal = abs((x - y) - size * 0.05) < stroke
            anti = abs((x + y) - size * 0.95) < stroke
            if amber and (diagonal or anti or distance > radius - stroke * 1.4):
                color = (244, 240, 234)
            elif amber:
                color = (217, 164, 65)
            else:
                color = (16, 17, 19)
            row.extend(color)
        rows.append(bytes(row))
    raw = b"".join(rows)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)


images = [
    ("Icon-App-20x20@2x.png", "20x20", "iphone", "2x", 40),
    ("Icon-App-20x20@3x.png", "20x20", "iphone", "3x", 60),
    ("Icon-App-29x29@2x.png", "29x29", "iphone", "2x", 58),
    ("Icon-App-29x29@3x.png", "29x29", "iphone", "3x", 87),
    ("Icon-App-40x40@2x.png", "40x40", "iphone", "2x", 80),
    ("Icon-App-40x40@3x.png", "40x40", "iphone", "3x", 120),
    ("Icon-App-60x60@2x.png", "60x60", "iphone", "2x", 120),
    ("Icon-App-60x60@3x.png", "60x60", "iphone", "3x", 180),
    ("Icon-App-20x20@1x.png", "20x20", "ipad", "1x", 20),
    ("Icon-App-20x20@2x-ipad.png", "20x20", "ipad", "2x", 40),
    ("Icon-App-29x29@1x.png", "29x29", "ipad", "1x", 29),
    ("Icon-App-29x29@2x-ipad.png", "29x29", "ipad", "2x", 58),
    ("Icon-App-40x40@1x.png", "40x40", "ipad", "1x", 40),
    ("Icon-App-40x40@2x-ipad.png", "40x40", "ipad", "2x", 80),
    ("Icon-App-76x76@1x.png", "76x76", "ipad", "1x", 76),
    ("Icon-App-76x76@2x.png", "76x76", "ipad", "2x", 152),
    ("Icon-App-83.5x83.5@2x.png", "83.5x83.5", "ipad", "2x", 167),
    ("Icon-App-1024x1024@1x.png", "1024x1024", "ios-marketing", "1x", 1024),
]

icon_dir = Path(sys.argv[1])
icon_dir.mkdir(parents=True, exist_ok=True)
for filename, _, _, _, size in images:
    write_png(icon_dir / filename, size)

contents = {
    "images": [
        {
            "filename": filename,
            "idiom": idiom,
            "scale": scale,
            "size": logical_size,
        }
        for filename, logical_size, idiom, scale, _ in images
    ],
    "info": {"author": "xcode", "version": 1},
}
(icon_dir / "Contents.json").write_text(
    json.dumps(contents, ensure_ascii=False, indent=2),
    encoding="utf-8",
)
PY

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

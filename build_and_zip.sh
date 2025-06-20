#!/usr/bin/env bash
set -e

echo "💡 Fetching Dart packages..."
flutter pub get

echo "💡 Building Flutter Web..."
flutter build web --release

echo "💡 Zipping output..."
# Remove existing zip if present
[ -f deploy.zip ] && rm deploy.zip
# Zip contents of build/web into deploy.zip
(cd build/web && zip -r ../../deploy.zip .)

echo "✅ Created deploy.zip"

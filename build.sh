#!/bin/bash
set -e

echo "Downloading Flutter SDK..."
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.0-stable.tar.xz | tar xJ

export PATH="$PATH:$(pwd)/flutter/bin"

# Fix git ownership issue on Vercel
git config --global --add safe.directory "$(pwd)/flutter"

echo "Flutter version:"
flutter --version

echo "Enabling web..."
flutter config --enable-web

echo "Getting dependencies..."
cd frontend
flutter pub get

echo "Building web app..."
flutter build web --release

echo "Build complete!"
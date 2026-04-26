#!/bin/bash
set -e

# Download Flutter
echo "Downloading Flutter..."
git clone https://github.com/flutter/flutter.git -b stable ../flutter
export PATH="$PATH:`pwd`/../flutter/bin"

# Enable web
flutter config --enable-web

# Get dependencies
echo "Getting dependencies..."
cd frontend
flutter pub get

# Build web app
echo "Building Flutter Web app..."
flutter build web --release

#!/bin/bash
curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.0-stable.tar.xz | tar xJ
export PATH="$PATH:$(pwd)/flutter/bin"
cd frontend
flutter pub get
flutter build web
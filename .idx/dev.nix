# Project IDX workspace configuration
# This file tells IDX exactly what tools to install automatically
{ pkgs, ... }: {
  channel = "stable-23.11";

  packages = [
    pkgs.python311
    pkgs.python311Packages.pip
    pkgs.nodejs_20
    pkgs.nodePackages.firebase-tools
  ];

  # Flutter is handled by IDX's built-in Flutter support
  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
      "ms-python.python"
      "GoogleCloudTools.firebase-dataconnect-vscode"
    ];

    previews = {
      enable = true;
      previews = {
        web = {
          command = [
            "flutter"
            "run"
            "--machine"
            "-d"
            "web-server"
            "--web-hostname"
            "0.0.0.0"
            "--web-port"
            "$PORT"
          ];
          manager = "flutter";
          cwd = "flutter_app";
        };
      };
    };

    workspace = {
      onCreate = {
        install-functions-deps = {
          command = "cd functions && pip install -r requirements.txt";
          description = "Install Firebase Functions Python dependencies";
        };
        install-flutter-deps = {
          command = "cd flutter_app && flutter pub get";
          description = "Install Flutter dependencies";
        };
      };

      onStart = {
        functions-emulator = {
          command = "firebase emulators:start --only functions,firestore,storage,auth";
          description = "Start Firebase emulators for local dev";
        };
      };
    };
  };
}

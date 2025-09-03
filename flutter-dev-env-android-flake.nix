{
  description = "Flutter + Android SDK Dev Shell with writable SDK, automatic licenses, NDK, cmdline-tools, and emulator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, android-nixpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        androidEnv = android-nixpkgs.sdk.${system} (sdkPkgs: with sdkPkgs; [
          cmdline-tools-latest
          build-tools-34-0-0
          platform-tools
          platforms-android-34
          emulator
          ndk-25-2-9519653
        ]);

        flutterSdk = pkgs.flutter.overrideAttrs (_: {
          src = pkgs.fetchgit {
            url = "https://github.com/flutter/flutter.git";
            rev = "3.22.2";
            sha256 = "sha256-7ndnIw72YxNB+VeeejEeRD+xxuLXOcWo322s5CMWzBM=";
          };
        });

        flutterWrapper = pkgs.writeShellScriptBin "flutter" ''
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
            pkgs.zlib
            pkgs.libgcc
            pkgs.stdenv.cc.cc.lib
          ]}"
          exec ${flutterSdk}/bin/flutter "$@"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          name = "flutter-android-dev-env";

          buildInputs = [
            pkgs.bashInteractive
            pkgs.git
            pkgs.cmake
            pkgs.ninja
            pkgs.python3
            pkgs.jdk17
            pkgs.gradle
            androidEnv
            flutterWrapper
          ];

          shellHook = ''
            #set -e

            export ANDROID_HOME="$PWD/.android/sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export JAVA_HOME="${pkgs.jdk17}"

            # Ensure all SDK directories exist
            mkdir -p "$ANDROID_HOME/licenses"
            mkdir -p "$ANDROID_HOME/avd"
            mkdir -p "$ANDROID_HOME/bin"
            mkdir -p "$ANDROID_HOME/platform-tools"
            mkdir -p "$ANDROID_HOME/emulator"
            mkdir -p "$ANDROID_HOME/ndk/25.2.9519653"
            mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
            mkdir -p "$ANDROID_HOME/platforms/android-34"
            mkdir -p "$ANDROID_HOME/build-tools/34.0.0"

            # Copy SDK components
            cp -LR ${androidEnv}/share/android-sdk/cmdline-tools/latest/* "$ANDROID_HOME/cmdline-tools/latest/"
            cp -LR ${androidEnv}/share/android-sdk/ndk/25.2.9519653/* "$ANDROID_HOME/ndk/25.2.9519653/"
            cp -LR ${androidEnv}/share/android-sdk/platform-tools/* "$ANDROID_HOME/platform-tools/"
            cp -LR ${androidEnv}/share/android-sdk/emulator/* "$ANDROID_HOME/emulator/"
            cp -LR ${androidEnv}/share/android-sdk/platforms/android-34/* "$ANDROID_HOME/platforms/android-34/"
            cp -LR ${androidEnv}/share/android-sdk/build-tools/34.0.0/* "$ANDROID_HOME/build-tools/34.0.0/"

            # Copy essential binaries
            for bin in adb avdmanager emulator sdkmanager; do
              cp -LR ${androidEnv}/bin/$bin "$ANDROID_HOME/bin/" || true
            done

            # Fix permissions
            chmod -R u+w "$ANDROID_HOME"
            find "$ANDROID_HOME/bin" "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/emulator" \
                 "$ANDROID_HOME/cmdline-tools/latest/bin" "$ANDROID_HOME/build-tools" \
                 "$ANDROID_HOME/platforms" "$ANDROID_HOME/ndk" -type f -exec chmod +x {} \;

            # Accept licenses
            for license in android-sdk-license android-sdk-preview-license googletv-license; do
              touch "$ANDROID_HOME/licenses/$license"
            done
            yes | flutter doctor --android-licenses || true
            echo "✅ Android SDK licenses accepted."

            # Configure Flutter
            flutter config --android-sdk "$ANDROID_HOME"

            # Setup local.properties
            if [ -d "android" ]; then
              mkdir -p android
              echo "sdk.dir=$ANDROID_SDK_ROOT" > android/local.properties
              echo "flutter.sdk=$(cd $(dirname $(command -v flutter))/.. && pwd)" >> android/local.properties
              echo "Wrote android/local.properties"
            fi

            # Patch android/app/build.gradle
            if [ -f "android/app/build.gradle" ]; then
              if ! grep -q 'flutter_tools/gradle/flutter.gradle' android/app/build.gradle; then
                cat >> android/app/build.gradle <<'EOF'
def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
  throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}
apply plugin: 'com.android.application'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"
EOF
                echo "Patched android/app/build.gradle to include flutter.gradle"
              fi
            fi

            flutter doctor --quiet
            echo "✅ Flutter + Android dev shell ready."
          '';
        };
      }
    );
}


{
  description = "Flutter + Android SDK Dev Shell using FHS environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
          build-tools-36-0-0
          platform-tools
          platforms-android-36
          emulator
          ndk-26-1-10909125
          system-images-android-36-google-apis-playstore-x86-64
        ]);

        # Create FHS environment for Android development
        fhsEnv = pkgs.buildFHSUserEnv {
          name = "flutter-android-fhs";
          targetPkgs = pkgs: with pkgs; [
            git
            cmake
            ninja
            python3
            jdk17
            gradle
            flutter
            androidEnv
            # Additional libraries that Android tools might need
            stdenv.cc.cc.lib
            zlib
            glibc
            libGL
            libGLU
            xorg.libX11
            xorg.libXext
            xorg.libXrender
            fontconfig
            freetype
            ncurses5
            ncurses
          ];
          
          runScript = "bash";
          
          extraInstallCommands = ''
            mkdir -p $out/etc
            echo "nameserver 8.8.8.8" > $out/etc/resolv.conf
          '';
        };

      in
      {
        devShells.default = fhsEnv.env.overrideAttrs (oldAttrs: {
          shellHook = ''
            export JAVA_HOME="${pkgs.jdk17}"
            export ANDROID_HOME="$PWD/.android/sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            
            # Create Android SDK directory structure
            mkdir -p "$ANDROID_HOME"/{licenses,avd,bin}
            
            # Copy Android SDK
            cp -LR ${androidEnv}/share/android-sdk/* "$ANDROID_HOME/" || true
            
            # Copy binaries
            for bin in adb avdmanager emulator sdkmanager; do
              cp -LR ${androidEnv}/bin/$bin "$ANDROID_HOME/bin/" || true
            done
            
            chmod -R u+w "$ANDROID_HOME"
            find "$ANDROID_HOME" -type f -name "*.sh" -o -name "adb" -o -name "emulator" -o -name "aapt*" | xargs chmod +x
            
            # Accept licenses
            for license in android-sdk-license android-sdk-preview-license googletv-license; do
              echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > "$ANDROID_HOME/licenses/$license"
            done
            
            flutter config --android-sdk "$ANDROID_HOME"
            
            # Create Flutter project if needed
            if [ ! -f pubspec.yaml ]; then
              flutter create .
            fi
            
            # Create AVD if missing
            if ! avdmanager list avd | grep -q 'android_emulator'; then
              yes | avdmanager create avd \
                --name "android_emulator" \
                --package "system-images;android-36;google_apis_playstore;x86_64" \
                --device "pixel" \
                --force
            fi
            
            echo "✅ FHS Flutter environment ready!"
            echo "👉 Try: flutter build apk --release"
          '';
        });
      }
    );
}

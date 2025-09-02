{
  description = "Minimal Android SDK shell for testing license handling";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        androidEnv = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "34" ];
          buildToolsVersions = [ "34.0.0" ];
          includeEmulator = false;
          includeNDK = false;
          toolsVersion = "26.1.1";
        };
      in {
        devShells.default = pkgs.mkShell {
          name = "android-test-shell";

          buildInputs = [
            pkgs.bashInteractive
            androidEnv.androidsdk
          ];

          shellHook = ''
            set -e
            export ANDROID_HOME="$HOME/.android/sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

            # Create SDK dir if missing
            mkdir -p "$ANDROID_HOME"
            mkdir -p "$ANDROID_HOME/licenses"

            # Copy SDK contents only if not present in $HOME
            if [ ! -d "$ANDROID_HOME/platforms" ]; then
              echo "➡️  Copying Android SDK to $ANDROID_HOME ..."
              cp -r ${androidEnv.androidsdk}/* "$ANDROID_HOME"/
            fi

            # Write dummy license files (never touches nix store!)
            for license in android-sdk-license android-sdk-preview-license googletv-license; do
              echo "accepted" > "$ANDROID_HOME/licenses/$license"
            done

            echo "✅ Test shell ready at $ANDROID_HOME"
          '';
        };
      }
    );
}


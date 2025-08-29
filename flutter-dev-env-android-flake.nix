{
  description = "Flutter development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    android.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, android, }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          android_sdk.accept_license = true;
        };
      };

      # The 'sdk' function is available directly on the `android` output
      # when the flake is evaluated for the current system.
      myAndroidSdk = android.sdk.${system} (sdkPkgs: with sdkPkgs; [
        platforms-android-34
        build-tools-34-0-0
        platform-tools
        cmdline-tools-latest
        emulator
        system-images-android-34-google-apis-playstore-x86-64 # find with nix flake show github:tadfisher/android-nixpkgs | grep system-images
      ]);

      # Define cmdlineToolsBin here so it's visible in the devShells definition
      cmdlineToolsBin = "${myAndroidSdk}/share/android-sdk/cmdline-tools/latest/bin";

    in {
      devShells.default = pkgs.mkShell {
        name = "flutter-dev-shell";

        packages = with pkgs; [
          flutter
          jdk
          myAndroidSdk
        ];

        shellHook = ''
          export ANDROID_HOME=${myAndroidSdk}/share/android-sdk
          export ANDROID_SDK_ROOT=${myAndroidSdk}share/android-sdk
          export PATH="$PATH:${cmdlineToolsBin}"
          export JAVA_HOME=${pkgs.jdk}
        '';
      };
    });
}


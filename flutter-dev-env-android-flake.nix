{
  description = "Flutter development environment (reproducible NixOS setup)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    android.url = "github:tadfisher/android-nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, android, }: 
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        # Compose Android SDK
        myAndroidSdk = android.sdk.${system} (sdkPkgs: with sdkPkgs; [
          platforms-android-34
          build-tools-34-0-0
          platform-tools
          cmdline-tools-latest
          ndk-26-3-11579264
          emulator
          system-images-android-34-google-apis-playstore-x86-64
        ]);

        cmdlineToolsBin = "${myAndroidSdk}/share/android-sdk/cmdline-tools/latest/bin";
        androidNdkRoot = "${myAndroidSdk}/share/android-sdk/ndk/26.3.11579264";

      in {
        devShells.default = pkgs.mkShell {
          name = "flutter-dev-shell";

          packages = with pkgs; [
            flutter
            jdk17
            myAndroidSdk
          ];

          shellHook = ''
            # Android SDK & NDK
            export ANDROID_HOME=${myAndroidSdk}/share/android-sdk
            export ANDROID_SDK_ROOT=$ANDROID_HOME
            export ANDROID_NDK_ROOT=${androidNdkRoot}
            export PATH=$PATH:${cmdlineToolsBin}

            # Java
            export JAVA_HOME=${pkgs.jdk17}

            # Isolated Gradle home inside project
            export GRADLE_USER_HOME=$PWD/.gradle
            mkdir -p $GRADLE_USER_HOME

            # Gradle options: safe daemon, polling file watcher
            export GRADLE_OPTS="-Dorg.gradle.daemon.idleTimeout=60 -Dorg.gradle.jvmargs=-Xmx8G"

            # Minimal fix: Add emulator folder to PATH
            export PATH=$PATH:${myAndroidSdk}/share/android-sdk/emulator

            echo "Flutter/Nix devShell ready!"
            echo "ANDROID_SDK_ROOT: $ANDROID_SDK_ROOT"
            echo "ANDROID_NDK_ROOT: $ANDROID_NDK_ROOT"
            echo "GRADLE_USER_HOME: $GRADLE_USER_HOME"
          '';
        };
      });
}


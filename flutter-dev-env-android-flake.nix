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
          buildInputs = [
            pkgs.flutter
            pkgs.jdk17
            myAndroidSdk
            pkgs.zlib
            pkgs.stdenv.cc.cc.lib
            pkgs.rlwrap
            pkgs.gradle
          ];

          shellHook = ''
            # Android SDK / NDK
            export ANDROID_HOME=${myAndroidSdk}/share/android-sdk
            export ANDROID_SDK_ROOT=$ANDROID_HOME
            export ANDROID_NDK_ROOT=${androidNdkRoot}
            export PATH=$PATH:${cmdlineToolsBin}:${myAndroidSdk}/share/android-sdk/emulator

            # Java
            export JAVA_HOME=${pkgs.jdk17}/lib/openjdk
            export PATH=$JAVA_HOME/bin:$PATH

            # Gradle
            export GRADLE_USER_HOME=$PWD/.gradle
            mkdir -p $GRADLE_USER_HOME

            export GRADLE_OPTS="-Dorg.gradle.daemon.idleTimeout=60 \
              -Dorg.gradle.jvmargs=-Xmx8G \
              -Dorg.gradle.vfs.watch=true \
              -Dorg.gradle.vfs.watch.mode=polling"

            # Minimal reproducible test setup
            mkdir -p "$PWD/etc"
            touch "$PWD/etc/ld-nix.so.preload"

            echo "Flutter + Android devShell ready!"
          '';
        };
      });
}


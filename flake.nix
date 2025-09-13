{
  description = "Flutter + Android SDK Dev Shell with writable SDK, automatic licenses, NDK, cmdline-tools, emulator, and system image";

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
          # ✅ include system image inside SDK instead of relying on sdkmanager. This ensures emulator functionality.
          system-images-android-36-google-apis-playstore-x86-64
        ]);

        # Create a patched Flutter derivation. This is the idiomatic Nix way.
        patchedFlutter = pkgs.flutter.overrideAttrs (oldAttrs: {
          # This patchPhase runs during the package's build time.
          patchPhase = ''
            runHook prePatch
            # This patch ensures Flutter's Gradle task uses the `cmake` from the
            # environment's PATH, rather than a hardcoded, absolute path.
            # This is crucial for making Flutter work reliably in a Nix environment.
            substituteInPlace $FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterTask.kt \
              --replace 'val cmakeExecutable = project.file(cmakePath).absolutePath' 'val cmakeExecutable = "cmake"'
            substituteInPlace $FLUTTER_ROOT/packages/flutter_tools/gradle/src/main/kotlin/FlutterTask.kt \
              --replace 'val ninjaExecutable = project.file(ninjaPath).absolutePath' 'val ninjaExecutable = "ninja"'
            runHook postPatch
          '';
        });

        # >>> PIN FOR COMPATIBILITY >>>
        androidBuildToolsVersion = "36.0.0";
        androidSdkVersion = "36";
        minSdkVersion = "21"; 
        gradleVersion = "8.1";
        kotlinVersion = "2.0.21";
        agpVersion = "8.12.3"; # Android Gradle Plugin

#########################################################################################################
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
            pkgs.nix-ld
            pkgs.gradle
            androidEnv
            patchedFlutter
          ];

          #  Critical nix-ld environment variables for dynamic linking compatibility
          NIX_LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            pkgs.stdenv.cc.cc
            pkgs.zlib
            pkgs.glibc
          ];
          
          NIX_LD = pkgs.lib.fileContents "${pkgs.stdenv.cc}/nix-support/dynamic-linker";

          shellHook = ''
            echo "Stopping any existing ADB server..."
            "${androidEnv}/share/android-sdk/platform-tools/adb" kill-server &> /dev/null || true
            mkdir -p "$PWD/.android/sdk"
            export ANDROID_HOME="$PWD/.android/sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export JAVA_HOME="${pkgs.jdk17}"

            # Verify Gradle + Java setup
            #echo "🔧 Using Gradle:"
            gradle --version

            echo "🔧 Using Java:"
            "$JAVA_HOME/bin/java" -version

            # Ensure all SDK directories exist
            mkdir -p "$ANDROID_HOME/licenses" "$ANDROID_HOME/avd" "$ANDROID_HOME/bin"

            # Copy over SDK parts including system-images now in androidEnv
            cp -LR ${androidEnv}/share/android-sdk/* "$ANDROID_HOME/" || true

            # Copy essential binaries
            for bin in adb avdmanager emulator sdkmanager; do
              cp -LR ${androidEnv}/bin/$bin "$ANDROID_HOME/bin/" || true
            done
	    rm -rf "$ANDROID_HOME/cmake"

            chmod -R u+w "$ANDROID_HOME"
            find "$ANDROID_HOME/bin" "$ANDROID_HOME/platform-tools" "$ANDROID_HOME/emulator" \
                 "$ANDROID_HOME/cmdline-tools/latest/bin" "$ANDROID_HOME/build-tools" \
                 "$ANDROID_HOME/platforms" "$ANDROID_HOME/ndk" -type f -exec chmod +x {} \;

            # Accept licenses
            for license in android-sdk-license android-sdk-preview-license googletv-license; do
              touch "$ANDROID_HOME/licenses/$license"
            done
            yes | flutter doctor --android-licenses || true

            flutter config --android-sdk "$ANDROID_HOME"

            # Create flutter project in root directory if one doesnt exist.
            if [ ! -f pubspec.yaml ]; then
              echo "No Flutter project found. Creating a new one..."
              flutter create .
            fi

            mkdir -p android/app/src/main/{kotlin,java}
            mkdir -p android/app/src/debug/{kotlin,java}
            mkdir -p android/app/src/profile/{kotlin,java}
            mkdir -p android/app/src/release/{kotlin,java}

            # Ensure android directories exist (avoid sed failures)
            mkdir -p android app

            if [ -d android ]; then
              # Create gradle.properties if it doesn't exist
              touch android/gradle.properties
              
              # Use sed to surgically remove existing properties to avoid duplicates  
              sed -i '/^android\.cmake\.path=/d' android/gradle.properties
              sed -i '/^android\.ninja\.path=/d' android/gradle.properties
              sed -i '/^android\.cmake\.version=/d' android/gradle.properties
              
              # Append new properties (preserves any other existing config)
              echo "android.cmake.path=${pkgs.cmake}/bin" >> android/gradle.properties
              echo "android.ninja.path=${pkgs.ninja}/bin" >> android/gradle.properties
              echo "android.cmake.version=" >> android/gradle.properties
            fi

            # Only patch if gradle.kts files exist
            if [ -f "android/build.gradle.kts" ]; then
              echo "⚙️ Pinning Android build tool versions in Kotlin DSL..."

              sed -i -e "s/id(\"com.android.application\") version \"[0-9.]*\"/id(\"com.android.application\") version \"${agpVersion}\"/g" android/build.gradle.kts
              sed -i -e "s/id(\"org.jetbrains.kotlin.android\") version \"[0-9.]*\"/id(\"org.jetbrains.kotlin.android\") version \"${kotlinVersion}\"/g" android/build.gradle.kts
            fi

            if [ -f "android/app/build.gradle.kts" ]; then
              sed -i -e "s/minSdk = [0-9a-zA-Z._]*/minSdk = ${minSdkVersion}/g" android/app/build.gradle.kts
            fi

	    #Support for traditional Groovy build files 
            if [ -f "android/build.gradle" ]; then
              echo "⚙️ Pinning Android build tool versions in Groovy DSL..."
              sed -i -e "s/com.android.application.*version.*'[0-9.]*'/com.android.application' version '${agpVersion}'/g" android/build.gradle
              sed -i -e "s/org.jetbrains.kotlin.android.*version.*'[0-9.]*'/org.jetbrains.kotlin.android' version '${kotlinVersion}'/g" android/build.gradle
            fi

            if [ -f "android/app/build.gradle" ]; then
              sed -i -e "s/minSdkVersion [0-9]*/minSdkVersion ${minSdkVersion}/g" android/app/build.gradle
            fi

            # Create AVD if missing
            if ! avdmanager list avd | grep -q 'android_emulator'; then
              echo "Creating default AVD: android_emulator"
              yes | avdmanager create avd \
                --name "android_emulator" \
                --package "system-images;android-36;google_apis_playstore;x86_64" \
                --device "pixel" \
                --abi "x86_64" \
                --tag "google_apis_playstore" \
                --force
            fi

            # ✅ ADDED: Enhanced PATH and tool verification (enhancements over original)
            export PATH="${pkgs.cmake}/bin:${pkgs.ninja}/bin:$PATH"
            
            # Verify our tools are accessible
            echo "🔧 Using CMake: $(which cmake) ($(cmake --version | head -1))"
            echo "🔧 Using Ninja: $(which ninja) ($(ninja --version))"

            flutter doctor --quiet
            echo "✅ Flutter + Android dev shell ready."

            echo "👉 To launch the emulator, run:"
            echo "   emulator -avd android_emulator"
            
            echo ""
            echo "👉 To build your app, run:"
            echo "   flutter build apk --release"
          '';
        };
      }
    );
}

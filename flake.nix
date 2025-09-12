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

        # ✅ Create a patched Flutter derivation. This is the idiomatic Nix way.
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
	    substituteInPlace packages/flutter_tools/gradle/src/main/scripts/CMakeLists.txt \
	      --replace-fail "/cmake/3.22.1/bin/ninja" "${pkgs.ninja}/bin/ninja"

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

          shellHook = ''
	    # Crucial fix for NixOS and dynamic executables
	    export GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidEnv}/share/android-sdk/build-tools/36.0.0/aapt2 -Dorg.gradle.project.android.cmake.path=${pkgs.cmake}/bin/cmake"
	  
	    mkdir -p "$PWD/.android/sdk"
            export ANDROID_HOME="$PWD/.android/sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export JAVA_HOME="${pkgs.jdk17}"
	    export CMAKE_MAKE_PROGRAM=${pkgs.ninja}/bin/ninja

	    # --- START of Fixes for Dynamic Executables ---
	    # Create a writeable directory to store fixes for dynamically linked executables.
	    mkdir -p "$PWD/.android-patches"

	    # Create a symlink to Nix's compatible cmake, as the Android SDK version is not compatible.
	    ln -sf ${pkgs.cmake}/bin/cmake "$PWD/.android-patches/cmake"

	    # Create a symlink to Nix's compatible ninja, as the Android SDK version is not compatible.
	    #ln -sf ${pkgs.ninja}/bin/ninja "$PWD/.android-patches/ninja"

	    # Add the patches directory to the PATH to ensure they are found first.
	    export PATH="$PWD/.android-patches:$PATH"
	    patchelf --set-rpath /run/current-system/sw/lib /home/tim/projects/flakes/.android/sdk/cmake/3.22.1/bin/ninja

	    # --- END of Fixes for Dynamic Executables ---

            # Verify Gradle + Java setup
	    #echo "🔧 Using Gradle:"
	    gradle --version

            echo "🔧 Using Java:"
            "$JAVA_HOME/bin/java" -version

            # Ensure all SDK directories exist
            mkdir -p "$ANDROID_HOME/licenses" "$ANDROID_HOME/avd" "$ANDROID_HOME/bin"

            export ANDROID_HOME="$PWD/.android/sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export JAVA_HOME="${pkgs.jdk17}"

            mkdir -p "$ANDROID_HOME/licenses" "$ANDROID_HOME/avd" "$ANDROID_HOME/bin"

            # Copy over SDK parts including system-images now in androidEnv
            cp -LR ${androidEnv}/share/android-sdk/* "$ANDROID_HOME/" || true

            # Copy essential binaries
            for bin in adb avdmanager emulator sdkmanager; do
              cp -LR ${androidEnv}/bin/$bin "$ANDROID_HOME/bin/" || true
            done

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

	    # Create or update gradle.properties with the Nix-provided cmake path
	    if [ -d android ]; then
	      echo "android.cmake.dir=${pkgs.cmake}/bin" >> android/gradle.properties
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

            flutter doctor --quiet
            echo "✅ Flutter + Android dev shell ready."

            echo "👉 To launch the emulator, run:"
            echo "   emulator -avd android_emulator"
          '';
        };
      }
    );
}

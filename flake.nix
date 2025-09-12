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

        flutterWrapper = pkgs.writeShellScriptBin "flutter" ''
          export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
            pkgs.zlib
            pkgs.libgcc
            pkgs.stdenv.cc.cc.lib
	  ]};  
          exec ${pkgs.flutter}/bin/flutter "$@"
        '';

	# gradleTool = pkgs.stdenv.mkDerivation {
	#   pname = "gradle-tool";
	#   version = "8.6";
	#   src = pkgs.fetchurl {
	#     url = "https://services.gradle.org/distributions/gradle-8.6-bin.zip";
	#     sha256 = "sha256-ljHVPPPnS/pyaJOu4fiZT+5OBgxAEzWUbbohVvRA8kw=";
	#   };
	#   dontUnpack = true;
	#   nativeBuildInputs = [ pkgs.unzip pkgs.git ];
	#   installPhase = ''
	#     mkdir -p $out
	#     unzip $src -d $out
	#     mkdir -p $out/bin
	#     ln -s $out/gradle-8.6/bin/gradle $out/bin/gradle 
	#   '';
	# };

        # >>> PIN FOR COMPATIBILITY >>>
	androidBuildToolsVersion = "36.0.0";
	androidSdkVersion = "36";
        gradleVersion = "8.6";
        kotlinVersion = "2.0.21";
        agpVersion = "8.4.0"; # Android Gradle Plugin

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
	    pkgs.gradle
            androidEnv
            flutterWrapper
	  ];  

          shellHook = ''
	    export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
    	      pkgs.zlib
    	      pkgs.stdenv.cc.cc.lib
	      pkgs.glibc
 	    ]};
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
            echo "✅ Android SDK licenses accepted."

            flutter config --android-sdk "$ANDROID_HOME"

	    #Create flutter project in root directory if one doesnt exist.
	    if [ ! -f pubspec.yaml ]; then
    	      echo "No Flutter project found. Creating a new one..."
    	      flutter create .
  	    fi

            # Check if the correct Kotlin Gradle file exists before attempting to modify it.
            if [ -f "android/build.gradle.kts" ]; then
              echo "⚙️ Pinning Android build tool versions in Kotlin DSL..."

              # Use sed to update the AGP version in build.gradle.kts
              sed -i -e "s/id(\"com.android.application\") version \"[0-9.]*\"/id(\"com.android.application\") version \"${agpVersion}\"/g" android/build.gradle.kts
              
              # Use sed to update the Kotlin version in build.gradle.kts
              sed -i -e "s/id(\"org.jetbrains.kotlin.android\") version \"[0-9.]*\"/id(\"org.jetbrains.kotlin.android\") version \"${kotlinVersion}\"/g" android/build.gradle.kts
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

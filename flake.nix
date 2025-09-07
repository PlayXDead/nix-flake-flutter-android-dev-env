{
  description = "Flutter + Android SDK Dev Shell with writable SDK, automatic licenses, NDK, cmdline-tools, emulator, and system image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
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
          build-tools-36-0-0
          platform-tools
          platforms-android-36
          emulator
          ndk-26-1-10909125
          # ✅ include system image inside SDK instead of relying on sdkmanager. This ensures emulator functionality.
          system-images-android-36-google-apis-playstore-x86-64
        ]);

        flutterWrapper = pkgs.writeShellScriptBin "flutter" ''
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
            pkgs.zlib
            pkgs.libgcc
            pkgs.stdenv.cc.cc.lib
	  ]}"  
	  if [ "$1" = "create" ]; then
	    exec ${pkgs.flutter}/bin/flutter "$@" --no-git
	  else
	    exec ${pkgs.flutter}/bin/flutter "$@"
	  fi
        '';

	gradleTool = pkgs.stdenv.mkDerivation {
	  pname = "gradle-tool";
	  version = "8.6";
	  src = pkgs.fetchurl {
	    url = "https://services.gradle.org/distributions/gradle-8.6-bin.zip";
	    sha256 = "sha256-ljHVPPPnS/pyaJOu4fiZT+5OBgxAEzWUbbohVvRA8kw=";
	  };
	  dontUnpack = true;
	  nativeBuildInputs = [ pkgs.unzip ];
	  installPhase = ''
	    mkdir -p $out
	    unzip $src -d $out
	    mkdir -p $out/bin
	    ln -s $out/gradle-8.6/bin/gradle $out/bin/gradle 
	  '';
	};

        # >>> PIN FOR COMPATIBILITY >>>
	androidBuildToolsVersion = "36.0.0";
	androidSdkVersion = "36";
        gradleVersion = "8.6";
        kotlinVersion = "2.0.21";
        agpVersion = "8.5.0"; # Android Gradle Plugin

        # >>>Gradle & Kotlin version Compatibility in build.kts etc.
	flutterBuildConfigs = pkgs.stdenv.mkDerivation {
	  name = "flutter-build-configs";
	  src = ./.;
	  nativeBuildInputs = [ pkgs.flutter ];
	  dontUnpack = true;

	  buildPhase = ''
	    # Make the home directory writable for the build.
	    export HOME="$(pwd)/.home"
	    mkdir -p "$HOME"

	    # Set a writable Flutter root for the build process
	    export FLUTTER_ROOT="$(pwd)/.flutter_root"

	    flutter create .

	    mkdir -p android/gradle/wrapper android/app

	    cat > android/build.gradle <<EOF
	      // Top-level build file where you can add configuration options common to all sub-projects/modules.
	      buildscript {
		ext.kotlin_version = '${kotlinVersion}'
		repositories {
		    google()
		    mavenCentral()
		}
		dependencies {
		    classpath 'com.android.tools.build:gradle:${agpVersion}'
		    classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
		}
	      }
	      allprojects {
		repositories {
		    google()
		    mavenCentral()
		}
	      }
	      tasks.register('clean', Delete) {
		delete rootProject.buildDir
	      }
	    EOF

	    cat > android/build.gradle.kts <<EOF
	      buildscript {
		  val kotlin_version by extra("${kotlinVersion}")
		  val agp_version by extra("${agpVersion}")
		  repositories {
		      google()
		      mavenCentral()
		  }
		  dependencies {
		      classpath("com.android.tools.build:gradle:$agp_version")
		      classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
		  }
	      }
	      allprojects {
		  repositories {
		      google()
		      mavenCentral()
		  }
	      }
	    EOF
	    
	    cat > android/gradle/wrapper/gradle-wrapper.properties <<EOF
	      distributionBase=GRADLE_USER_HOME
	      distributionUrl=https://services.gradle.org/distributions/gradle-${gradleVersion}-all.zip
	      distributionPath=wrapper/dists
	      zipStoreBase=GRADLE_USER_HOME
	      zipStorePath=wrapper/dists
	    EOF

	# Generate android/app/build.gradle with pinned Kotlin version.
	    cat > android/app/build.gradle <<EOF
	      def localProperties = new Properties()
	      def localPropertiesFile = rootProject.file('local.properties')
	      if (localPropertiesFile.exists()) {
		  localPropertiesFile.withReader('UTF-8') { reader ->
		      localProperties.load(reader)
		  }
	      }
	      def flutterRoot = localProperties.getProperty('flutter.sdk')
	      if (flutterRoot == null) {
		  throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
	      }
	      def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
	      if (flutterVersionCode == null) {
		  flutterVersionCode = '1'
	      }
	      def flutterVersionName = localProperties.getProperty('flutter.versionName')
	      if (flutterVersionName == null) {
		  flutterVersionName = '1.0'
	      }
	      apply plugin: 'com.android.application'
	      apply plugin: 'kotlin-android'
	      apply from: "\$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"
	      android {
		  compileSdkVersion ${androidSdkVersion}
		  defaultConfig {
		      applicationId "com.example.your_app"
		      minSdkVersion 21
		      targetSdkVersion 36
		      versionCode flutterVersionCode.toInteger()
		      versionName flutterVersionName
		      multiDexEnabled true
		  }
		  buildTypes {
		      release {
			  signingConfig signingConfigs.debug
		      }
		  }
	      }
	      flutter {
		  source '../..'
	      }
	      dependencies {
		  implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk8:${kotlinVersion}"
		    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.0.21")
	      }
	    EOF
	  '';

	  installPhase = ''
	    cp -r android $out
	  '';
	};

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
	    gradleTool
            androidEnv
            flutterWrapper
	    flutterBuildConfigs
	  ];  

          shellHook = ''
            export ANDROID_HOME="$PWD/.android/sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"
            export JAVA_HOME="${pkgs.jdk17}"

            # --- Gradle + Java configuration ---
            export PATH="${gradleTool}/bin:$PATH"
            export GRADLE_HOME="${gradleTool}"
            export ORG_GRADLE_JAVA_HOME="${pkgs.jdk17}"

            # Verify Gradle + Java setup
            echo "🔧 Using Gradle:"
            ${gradleTool}/bin/gradle --version

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

	    # Ensure the android directory and its contents are writable by the current user
	    # The `cp` command will fail otherwise if the directory or files lack permissions
	    # === NEW: This is the line to add ===
	    chmod -R u+w android/

	    # Pin gradle kotlin versions.
	    # Copy the generated build files ONLY if the android directory exists.
	    if [ -d "android" ]; then
	      echo "Copying pinned Gradle and Kotlin configurations..."
	      # === UPDATED: Now copying all generated files ===
	      cp -R ${flutterBuildConfigs}/android/* ./android/
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

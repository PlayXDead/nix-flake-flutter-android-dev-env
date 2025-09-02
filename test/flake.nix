{
  description = "Minimal flake to inspect androidenv SDK/NDK paths";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; config = { allowUnfree = true; }; };

        androidEnv = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "34" ];
          buildToolsVersions = [ "34.0.0" ];
          includeEmulator = false;
          includeNDK = true;
          toolsVersion = "26.1.1";
        };
      in {
        devShells.default = pkgs.mkShell {
          name = "android-test-env";

          buildInputs = [ androidEnv.androidsdk ];

          shellHook = ''
            echo "Android SDK path: ${androidEnv.androidsdk}"
            echo "NDK packages:"
            for ndk in ${pkgs.lib.concatStringsSep " " androidEnv.ndkPackages}; do
              echo "  $ndk"
            done
          '';
        };
      }
    );
}


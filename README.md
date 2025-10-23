# Overview 

This flake provides a development environment for building and testing Flutter Android projects. It includes the necessary tools, such as Flutter, CMake, Ninja, and the Android SDK, to create, build, and run Android apps. 
Getting Started 

* Create a new directory: Create a new directory for your project 
* Clone this repository: Clone this repository (or download the flake.nix file) and place the "flake.nix" in your project directory
* Run nix develop: Navigate to your project directory with the flake.nix. Run nix develop to enter the development shell
     

# Features 

Flutter SDK for building Android apps
CMake and Ninja build systems for native code integration
Android SDK for creating, testing, and running Android apps
Kotlin and Gradle for building and managing Android projects
NDK (Native Development Kit) support for adding native code to your project
     

# Troubleshooting 

Verify the NDK version: Check that the ndkVersion variable in flake.nix matches the available versions in your Nixpkgs channel.
Check the architecture: Ensure that the system = "x86_64-linux" line is correct for your system architecture.
Force Environment Rebuld: remove ".flutter_env_ready" and the .android folder. After performing nix develop, the environment should be re-established.

# Planned Future Improvements

* swap out my custom wrapper for the emulator with nixGL for better compatibility with certain Wayland compositors such as Niri & Hyprland. This Should also improve compatibility with non nixos systems. I should be working on this within weeks from this commit.
     

# License 

This flake is licensed under the MIT License . 

README

Flake is still in development. Most Major hurldes have been overcome but improvements are still needed. 


    Due to flake generating an FHSEnv shell, "flutter create ." does not initialize a git repo automatically, the flake now intiates a git repo directly after flutter create and submits initial commit. Currently have an issue with .flutter_env_ready cluttering the .gitignore.
    place flake in a new project directory and run "nix develop". this will generate the new flutter project and all tooling.
    .android/sdk is added automatically to your .gitignore you should consider adding more directories.
    i reccomend being sure to commit anytime you've finished making changes before re-entering the shell to keep shell re-entry fast.

*Current Known Issues

    emulator hardware buttons (power home volume etc) are currently not functioning. i hope to have this fixed soon
    Physical Keyboard input not detected by emulator. (emulators running great however and onscreen touch keyboard functions).


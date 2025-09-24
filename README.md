                TEMPORARY README: 
flake is still in devlopment.
Most major hurdles have been overcome but
impromvements are needed. Be aware as I'm also new
to learning git and how nix interacts, the name 
of the repository may change.

1. Due to flake generating an FHSEnv shell, 
"flutter create ." does not initialize a git repo automatically, the flake now intiates a git repo directly after flutter create and submits initial commit. Currently have an issue with .flutter_env_ready cluttering the .gitignore.
2. place flake in a new project directory and run
   "nix develop". this will generate the new
   flutter project and all tooling.
3. .android/sdk is added automatically to your .gitignore you should consider adding more directories.
5. i reccomend being sure to commit anytime you've
   finished making changes before re-entering the shell
   to keep shell re-entry fast.

######################
CURRENT KNOWN ISSUES
######################
1. emulator hardware buttons (power home volume etc) are currently not functioning. i hope to have this fixed soon
2. Physical Keyboard input not detected by emulator. (emulators running great however and onscreen touch keyboard functions).

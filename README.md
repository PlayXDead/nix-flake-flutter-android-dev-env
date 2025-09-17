################################################
                TEMPORARY README: 
flake is still in devlopment.
Most major hurdles have been overcome but
impromvements are needed. Be aware as I'm also new
to learning git and how nix interacts, the name 
of the repository may change.
################################################
1. Due to flake generating an FHSEnv shell, 
"flutter create ." does not initialize a git repo
2. place flake in a new project directory and run
   "nix develop". this will generate the new
   flutter project and all tooling.
3. Currently you will need to add .android/sdk
   to your .gitignore. this will massively speedup
   shell re-entry and prevent you from hitting any
   data limits with git. I will have the flake do
   this automatically in the near future
4. i reccomend being sure to commit anytime you've
   finished making changes before re-entering the shell
   to keep shell re-entry fast.

######################
CURRENT KNOWN ISSUES
######################
1. BE SURE TO ADD ".android/sdk" to gitignore this is critical
2. emulator hardware buttons (power home volume etc) are currently not functioning. i hope to have this fixed soon

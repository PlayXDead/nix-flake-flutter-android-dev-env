########################################################################################
                TEMPORARY README: 
flake is still in devlopment.
Most major hurdles have been overcome but
impromvements are needed. Be aware as I'm also new
to learning git and how nix interacts, the name 
of the repository may change to the flake name.
########################################################################################
1. Due to flake generating an FHSEnv shell, "flutter create ." does not initialize a git repo however the flake now does this for you if none is found. 

2. place flake in a new project directory and run
   "nix develop". this will generate the new
   flutter project and all tooling.

4. i reccomend being sure to commit anytime you've finished making changes before re-entering the shell to keep shell re-entry fast.

#########################################################################################
CURRENT KNOWN ISSUES
#########################################################################################
1. emulator hardware buttons (power home volume etc) are currently not functioning. i hope to have this fixed soon. 

Please reach out if you have any issues with this flake. 

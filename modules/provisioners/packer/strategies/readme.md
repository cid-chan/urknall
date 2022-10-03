Packer Strategies:
These define how packer will attempt to build the golden image.

The following strategies exist:

- _partitioner
  Will produce a script that partitions a device and mounts those partitions.
  This strategy is as part of other strategies.
  Files:
  - default.nix
    Creates a script that is run on the remote machine to format the disk and mount the folders.
  - submodule.nix
    A submodule define that is suitable for reuse.

- rescue
  Assumes a SSH server running on a rescue system that can be connected via ssh.
  Nix is installed on the rescue system,
  which is then used to transfer data to it.
  - default.nix: 
    Creates a script that takes a rescue system (non-nix), and installs NixOS on it.
  - submodule.nix:
    Defines a submodule to use as an option.

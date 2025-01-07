# SSH Keys

This directory contains a number of SSH keys.
Despite appearances, their presence in the Git repo is not a security risk.

## Root SSH Key

This key is used temporarily when provisioning the VM.
It's later removed from the VM prior to conversion into a Vagrant box.

## Vagrant Keys

These are well-know keys that are used by Vagrant when first bringing up a VM.
Their source of truth is [here](https://github.com/hashicorp/vagrant/tree/main/keys).

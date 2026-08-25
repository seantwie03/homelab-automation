# CLI

Install and configure CLI environment for user specified in `user` variable.

## agg

The asciinema GIF generator is installed from the x86_64 standalone binary
attached to its GitHub release. The version and SHA-256 checksum published in
the GitHub release metadata are pinned in `vars/main.yml` and should be updated
together when upgrading agg.

## Yazi

Yazi is installed from the unofficial `lihaohong/yazi` COPR because it is not
packaged in the Fedora repositories.

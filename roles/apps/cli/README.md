# CLI

Install and configure CLI environment for user specified in `user` variable.

The role depends on the Node.js, .NET, and Rust runtime roles. Neovim plugins
use Node.js, Mason requires `dotnet` to install the Roslyn language server, and
`cargo` installs pyroclear.

## agg

The asciinema GIF generator is installed from the x86_64 standalone binary
attached to its GitHub release. The version and SHA-256 checksum published in
the GitHub release metadata are pinned in `vars/main.yml` and should be updated
together when upgrading agg.

## pyroclear

pyroclear is installed from crates.io into `~/bin` with `cargo install --locked`.
kitty-demo uses it to burn the screen away at section changes during live
demonstrations, and falls back to a plain `clear` without it. The version is
pinned in `vars/main.yml`. Before raising it, confirm that `--random`,
`--no-save`, and the `[animation]` keys in kitty-demo's
`kittydemo/config/pyroclear/config.toml` still behave the same, since kitty-demo
depends on all three.

## Yazi

Yazi is installed from the unofficial `lihaohong/yazi` COPR because it is not
packaged in the Fedora repositories.

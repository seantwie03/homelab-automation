# imgman

Builds this repository's bootc images and tests them in VMs that stand in for
the hosts in `images/hosts.toml`, each installed with the host's kickstart.

The command line parses and checks its arguments, `hosts.toml`, and
prerequisites. The commands themselves are not implemented yet: each exits 3
with "not implemented yet".

## Installing

From the repository root:

```sh
uv tool install --editable imgman
```

imgman reads the checkout it was installed from, so it works only from an
editable install.

## Changing imgman

imgman uses only the Python standard library. The development tools are in
the `dev` dependency group, pinned in `uv.lock`. After any change, run these
from this directory. All four must pass before committing:

```sh
uv run ruff format
uv run ruff check
uv run pyrefly check
uv run pytest
```

# Emacs configuration

## Tests

Run the custom function tests against the installed configuration:

```sh
~/.config/emacs/scripts/test
```

To run the tests from within Emacs:

1. Run `M-x load-file` and select `~/.config/emacs/tests/init-test.el`.
2. Run `M-x ert`, enter `t` for the test selector, and press `RET`.

The tests use ERT and call the custom functions directly. Keybinding coverage
is maintained separately by the repository's Emacs configuration test skill.

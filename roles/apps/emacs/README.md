# emacs

Installs Fedora's default Emacs package and Pandoc for document preview and
export, creates `~/.config/emacs`, and symlinks the tracked startup files, test
runner, and tests from `dotfiles/emacs` into that directory. Emacs-generated
package, cache, and history files stay outside the repository in the regular
`~/.config/emacs` directory.

On graphical systems, the role installs `~/.local/share/applications/emacs.desktop`, which overrides Fedora's `/usr/share/applications/emacs.desktop` for the user. It keeps the same name, so taskbar pins and file associations still use it, but it runs `emacsclient --alternate-editor= --create-frame` instead of `emacs`. Every graphical launch opens a frame on the running Emacs server, and starts the Emacs daemon if no server is running. The daemon stops when its last frame closes (`server-stop-automatically` in `dotfiles/emacs/init.el`). The bash `em` and `emg` functions follow the same model. The override replaces the whole system entry, so compare it with the system file after a major Emacs package update.

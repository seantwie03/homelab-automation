# Fonts

Install fonts at system level, including
[Nerd Fonts](https://www.nerdfonts.com/), the symbols-only font used by
packages such as Emacs `nerd-icons`, and the upstream Iosevka Curly family.

Requires access to:

- https://github.com/ryanoasis/nerd-fonts/releases
- https://github.com/be5invis/Iosevka/releases

## Role Variables

`nerd_fonts_version`: The tag version from https://github.com/ryanoasis/nerd-fonts/releases

`iosevka_version`: The release version from https://github.com/be5invis/Iosevka/releases

`fonts`: The font(s) to download and install

########################################################################################################################
# bashrc
########################################################################################################################
# TODO:
# Steal some of this good stuff: https://gitlab.com/dwarmstrong/dotfiles/-/blob/master/.bashrc#L1

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Source global definitions
if [ -f /etc/bashrc ]; then
  source /etc/bashrc
fi

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

######################################## Functions ########################################
# This function returns 0 (true) if this script is being ran under WSL
function is_wsl {
  return $(grep -qi 'microsoft' /proc/version)
}

function update_neovim {
  curl -Lo /tmp/nvim-linux64.tar.gz https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
  tar -xvf /tmp/nvim-linux64.tar.gz --directory ~/.local/bin/
  ln -fs ~/.local/bin/nvim-linux64/bin/nvim ~/.local/bin/nvim
}

function update_lf {
  wget https://github.com/gokcehan/lf/releases/latest/download/lf-linux-amd64.tar.gz -O /tmp/lf-linux-amd64-latest.tar.gz
  tar -xvf /tmp/lf-linux-amd64-latest.tar.gz
  sudo mv /tmp/lf /usr/local/bin/lf
  sudo chmod 775 /usr/local/bin/lf
}

######################################## Defaults ########################################
EDITOR=/usr/bin/nvim
VISUAL=/usr/bin/code

# Allow ctrl-S for history navigation (with ctrl-R)
stty -ixon

# Make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Notify the terminal about the current working directory.
# This allows Windows Terminal to open new splits in the same directory.
if is_wsl ; then
  PROMPT_COMMAND=${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}'printf "\e]9;9;%s\e\\" "$(wslpath -w "$PWD")"'
fi

######################################## SSH Agent ########################################
if [ ! -S ~/.ssh/ssh_auth_sock ]; then
  eval `ssh-agent`
  ln -sf "$SSH_AUTH_SOCK" ~/.ssh/ssh_auth_sock
fi
export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock

######################################## History ########################################
# Setting history time format
HISTTIMEFORMAT="[%F %T] "

# Don't put duplicate lines or lines starting with space in the history. bash(1)
HISTCONTROL=ignoreboth

# Append to the history file, don't overwrite it
shopt -s histappend

# Setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=-1
HISTFILESIZE=-1

######################################## Prevent Clobber ########################################
# Prevent Clobber by Commands
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Prevent Clobber by Redirection - Bypass restriction with >|
set -o noclobber 

######################################## Color ######################################## 
alias ls='ls --almost-all --color=auto'
alias grep='grep --color=auto'

# Add Color to Man Pages
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

# Add Color to Prompt
# This is a great breakdown for how to set the colors: https://chrisyeh96.github.io/2020/03/28/terminal-colors.html
PS1='\[\033[0;34m\]\u\[\033[1;30m\]@\[\033[0;34m\]\h\[\033[1;30m\]:\[\033[0;36m\]\w\[\033[1;30m\]$ \[\033[0;30m\]'


######################################## Completion ########################################
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

######################################## Variables ########################################
# Windows Home (WH) - This variable is the linux-style path to the windows user's home directory
if is_wsl ; then
  # Apparently wslpath or PowerShell returns a \r on the end of the path which causes 'cd $WH' to not work. I 'fixed'
  # that by adding a sed substitution to remove the \r
  export WH="$(wslpath $(powershell.exe -NoProfile -NonInteractive -Command \$env:USERPROFILE) | sed 's/\r//')"
fi

######################################## bat ########################################
if command -v bat >/dev/null 2>&1 ; then
  export BAT_THEME='GitHub'
  alias less='bat --paging=always'
  alias cat='bat --paging=never --style=plain'
fi


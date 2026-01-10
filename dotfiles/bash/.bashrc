##########################################################################################
# bashrc
##########################################################################################
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[ -f /etc/bashrc ] && source /etc/bashrc
[ -f "$HOME"/.bash_functions ] && source $HOME/.bash_functions
[ -f "$HOME"/.bash_aliases ] && source $HOME/.bash_aliases

# User specific environment
if ! [[ "$PATH" =~ $HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin: ]]; then
  export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$PATH"
fi

######################################## Defaults ########################################
export EDITOR=/usr/bin/nvim
export VISUAL=/usr/bin/code

# Allow ctrl-S for history navigation (with ctrl-R)
stty -ixon

# Make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe.sh ] && export LESSOPEN="||/usr/bin/lesspipe.sh %s"

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

PROMPT_COMMAND="history -a; history -n; $PROMPT_COMMAND"

# Notify the terminal about the current working directory.
# This allows Windows Terminal to open new splits in the same directory.
if is_wsl ; then
  PROMPT_COMMAND=${PROMPT_COMMAND:+"$PROMPT_COMMAND; "}'printf "\e]9;9;%s\e\\" "$(wslpath -w "$PWD")"'
fi

shopt -s autocd
shopt -s globstar
shopt -s nocaseglob

######################################## SSH Agent ########################################
if is_wsl; then
    alias ssh="ssh.exe"
    alias ssh-add="ssh-add.exe"
else
    if [ ! -S ~/.ssh/ssh_auth_sock ]; then
      eval "$(ssh-agent)"
      ln -sf "$SSH_AUTH_SOCK" ~/.ssh/ssh_auth_sock
    fi
    export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock
fi

######################################## History ########################################
HISTSIZE=
HISTFILESIZE=
HISTTIMEFORMAT="[%F %T] "
HISTCONTROL=ignoreboth:erasedups
HISTIGNORE="ls:pwd:history"

shopt -s histappend
shopt -s cmdhist
shopt -s histverify

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
#PS1='\[\033[0;34m\]\u\[\033[1;30m\]@\[\033[0;34m\]\h\[\033[1;30m\]:\[\033[0;36m\]\w\[\033[1;30m\]$ \[\033[0;30m\]'
#PS1='\[\033[0;34m\]\u\[\033[1;30m\]@\[\033[0;34m\]\h\[\033[1;30m\]:\[\033[0;36m\]\w\[\033[0;30m\]$ '

####################################### Completion #######################################
# Load AWS CLI completion if available
if command -v aws &> /dev/null && command -v aws_completer &> /dev/null; then
  complete -C '/usr/local/bin/aws_completer' aws
fi

if command -v terraform &> /dev/null; then
  complete -C /usr/bin/terraform terraform
fi

######################################## Variables ########################################
# Windows Home (WH) - This variable is the linux-style path to the windows user's home directory
if is_wsl ; then
  # Apparently wslpath or PowerShell returns a \r on the end of the path which causes 'cd $WH' to not work. I 'fixed'
  # that by adding a sed substitution to remove the \r
  WH=$(wslpath "$(powershell.exe -NoProfile -NonInteractive -Command \$env:USERPROFILE)" | sed 's/\r//')
  export WH
fi

# Use libvirt with Vagrant
export VAGRANT_DEFAULT_PROVIDER='libvirt'


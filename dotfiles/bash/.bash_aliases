######################################## bat ########################################
if command -v bat >/dev/null 2>&1 ; then
  export BAT_THEME='GitHub'
  alias less='bat --paging=always'
  alias cat='bat --paging=never --style=plain'
fi

alias vim='nvim'

# For some reason dnf has separate cache for each user
# Always use root's cache
alias dnf='sudo dnf'

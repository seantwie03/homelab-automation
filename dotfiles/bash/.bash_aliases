######################################## bat ########################################
if command -v bat >/dev/null 2>&1 ; then
  alias less='bat --paging=always'
  alias cat='bat --paging=never --style=plain'
fi

alias vim='nvim'


#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
usage: query-emacs-eval.sh ELISP

Run one read-oriented Elisp expression through emacsclient.
This wrapper blocks common mutating, file, process, network, load, and eval forms.
EOF
    exit 2
}

join_regex_alternation() {
    local first=true
    local item

    for item in "$@"; do
        if [ "$first" = true ]; then
            printf '%s' "$item"
            first=false
        else
            printf '|%s' "$item"
        fi
    done
}

if [ "$#" -ne 1 ]; then
    usage
fi

expr=$1
symbol_boundary='[^[:alnum:]_+*/<>=!?$%&~^:.|-]'

allowed_start_forms=(
    and
    bound-and-true-p
    boundp
    buffer-file-name
    buffer-list
    buffer-local-variables
    buffer-name
    commandp
    cond
    current-active-maps
    default-value
    documentation
    documentation-property
    fboundp
    featurep
    find-library-name
    functionp
    if
    key-binding
    let
    let\\*
    list
    locate-library
    mapcar
    or
    package-installed-p
    progn
    save-current-buffer
    save-excursion
    save-window-excursion
    symbol-file
    symbol-value
    user-variable-p
    variable-p
    when
    where-is-internal
    with-current-buffer
)

blocked_forms=(
    add-hook
    append-to-file
    apply
    async-shell-command
    call-process
    call-process-region
    copy-file
    customize-set-variable
    defadvice
    defalias
    defcustom
    defun
    defvar
    delete-directory
    delete-file
    define-key
    eval
    fset
    funcall
    global-set-key
    insert
    kill-emacs
    load
    load-file
    make-directory
    make-process
    package-delete
    package-install
    provide
    read
    read-from-string
    remove-hook
    rename-file
    require
    set
    set-buffer
    set-default
    setq
    setq-default
    setopt
    shell-command
    start-process
    url-copy-file
    url-retrieve
    write-file
    write-region
)

for form in "${blocked_forms[@]}"; do
    if [[ $expr =~ (^|$symbol_boundary)$form($symbol_boundary|$) ]]; then
        echo "refusing expression containing blocked form: $form" >&2
        echo "ask the user whether this form should be added to the wrapper allowlist or handled manually" >&2
        exit 3
    fi
done

allowed_start_pattern=$(join_regex_alternation "${allowed_start_forms[@]}")
allowed_start_re="^[[:space:]]*\\(($allowed_start_pattern)([[:space:])]|$)"

if ! [[ $expr =~ $allowed_start_re ]]; then
    echo "refusing expression that does not start with an approved read-only form" >&2
    echo "ask the user whether this form should be added to the wrapper allowlist or handled manually" >&2
    exit 4
fi

exec emacsclient --eval "$expr"

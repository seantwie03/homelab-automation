# This function returns 0 (true) if this script is being ran under WSL
is_wsl() {
    grep -qi 'microsoft' /proc/version
    return $?
}

gsave() {
    git add -A
    git commit -m "$(date --iso-8601='minutes')"
    git push
}

gload() {
    git pull
}

gstat() {
    git status
}

locf() {
    if [ "$#" -eq 0 ]; then
        echo "usage: locf PATTERN..." >&2
        return 2
    fi

    locate -- "$@" |
        fzf \
            --scheme=path \
            --layout=reverse \
            --height=90% \
            --border \
            --prompt='locate> ' \
            --preview '
                if [ -d {} ]; then
                    ls -la -- {}
                else
                    bat --color=always --style=numbers --line-range=:200 -- {}
                fi
            '
}

# Open arguments in a Terminal Emacs frame attached to the running server
em() {
    if [ "$#" -eq 0 ]; then
        emacsclient -t -a ''
    else
        emacsclient -t -a '' -- "$@"
    fi
}

# Open arguments in a Graphical Emacs starting a new frame, if needed.
emg() {
     if is_wsl ; then
        local -a args=() a
        for a in "$@"; do
            case "$a" in
                 -*) args+=("$a") ;;
                 *)  args+=("$(wslpath -w "$a")") ;;
            esac
        done
        if [ "${#args[@]}" -eq 0 ]; then
           # Focus Emacs, will start a new frame, if needed.
           emacsclientw.exe -a runemacs -e "(select-frame-set-input-focus (selected-frame))" >/dev/null
        else
            # Open arguments in Emacs. Prefers existing frame but will spawn a new one if needed
            emacsclientw.exe -n -a runemacs -- "${args[@]}"
        fi
     else
        if [ "$#" -eq 0 ]; then
           # No file: raise the existing frame, or start Emacs if it is not running
            emacsclient -e "(select-frame-set-input-focus (selected-frame))" >/dev/null 2>&1 || { setsid emacs >/dev/null 2>&1 & }
        else
            # Open arguments in Emacs. Prefers existing frame but will spawn a new one, if needed.
            emacsclient -n -- "$@" >/dev/null 2>&1 || { setsid emacs "$@" >/dev/null 2>&1 & }
        fi
    fi
}

emo() {
    local emacs_eval

    emacs_eval='(progn
        (require (quote org-agenda))
        (setq org-agenda-window-setup (quote current-window))
        (find-file (expand-file-name "~/u/org/inbox.org"))
        (delete-other-windows)
        (let ((inbox-window (selected-window))
            (agenda-window (split-window-below)))
            (select-window agenda-window)
            (org-agenda-list)
            (select-window inbox-window)))'

    emacs -nw --chdir "$HOME/u/org" --eval "$emacs_eval"
}

# Move files or directories to the trash instead of deleting them outright.
# gio picks the trash directory belonging to each file's own filesystem, so
# this works the same on /home and on the NFS mount at /source, and the
# desktop Trash can restore each item to where it came from.
rmt() {
    if [ "$#" -eq 0 ]; then
        printf 'usage: rmt FILE...\n' >&2
        return 2
    fi

    if ! command -v gio >/dev/null 2>&1; then
        printf 'rmt: gio is not installed\n' >&2
        return 127
    fi

    # `--` stops a name that begins with a dash from being read as an option,
    # which gio otherwise rejects with "Unknown option".
    gio trash -- "$@" || return

    printf 'Trashed %d item(s).\n' "$#"
}

# Print characters in the entire asciinema recording area (120x32)
recording_area() {
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
    echo iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii
}

# This started as alias journalctlu='journalctl --user' but evolved into this craziness to make tab complete work
journalctlu() {
    journalctl --user "$@"
}
if [[ -r /usr/share/bash-completion/completions/journalctl ]]; then
    . /usr/share/bash-completion/completions/journalctl
fi

_journalctlu() {
    # Prepend '--user' to the words being completed so _journalctl sees it
    COMP_WORDS=(journalctl --user "${COMP_WORDS[@]:1}")
    ((COMP_CWORD+=1))
    _journalctl
}
complete -F _journalctlu journalctlu

# This started as alias systemctlu='systemctl --user' but evolved into this craziness to make tab complete work
systemctlu() {
    systemctl --user "$@"
}
if [[ -r /usr/share/bash-completion/completions/systemctl ]]; then
    . /usr/share/bash-completion/completions/systemctl
fi

_systemctlu() {
    # Prepend '--user' to the words being completed so _systemctl sees it
    COMP_WORDS=(systemctl --user "${COMP_WORDS[@]:1}")
    ((COMP_CWORD+=1))
    _systemctl
}
complete -F _systemctlu systemctlu

start-latest-snapshot() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: start-latest-snapshot HOSTNAME [HOSTNAME ...] | all" >&2
        return 2
    fi

    local hostname
    local vm_names
    local result=0
    local -a hostnames=()

    # Require "all" to be used by itself.
    for hostname in "$@"; do
        if [[ "$hostname" == "all" && $# -ne 1 ]]; then
            echo "'all' must be passed by itself." >&2
            return 2
        fi
    done

    if [[ "$1" == "all" ]]; then
        vm_names=$(
            virsh --connect qemu:///system list --all --name
        ) || return

        while IFS= read -r hostname; do
            if [[ -n "$hostname" ]]; then
                hostnames+=("$hostname")
            fi
        done <<< "$vm_names"

        if [[ ${#hostnames[@]} -eq 0 ]]; then
            echo "No VMs found."
            return 0
        fi
    else
        hostnames=("$@")
    fi

    for hostname in "${hostnames[@]}"; do
        printf '\nProcessing %s\n' "$hostname"

        if start-latest-snapshot-one "$hostname"; then
            printf 'Successfully restored %s\n' "$hostname"
        else
            printf 'Failed to restore %s; continuing.\n' "$hostname" >&2
            result=1
        fi
    done

    return "$result"
}

start-latest-snapshot-one() {
    if [[ $# -ne 1 || -z $1 ]]; then
        echo "Usage: start-latest-snapshot HOSTNAME" >&2
        return 2
    fi

    local hostname="$1"
    local snapshot_names
    local snapshot
    local creation_time
    local latest_snapshot=""
    local latest_creation_time=-1

    local -a virsh_command=(virsh --connect qemu:///system)

    # Display all snapshots for this VM.
    "${virsh_command[@]}" snapshot-list --domain "$hostname" || return

    snapshot_names=$(
        "${virsh_command[@]}" snapshot-list \
            --domain "$hostname" \
            --name
    ) || return

    if [[ -z "$snapshot_names" ]]; then
        printf 'No snapshots found for %s\n' "$hostname" >&2
        return 1
    fi

    # Find the snapshot with the newest creation time.
    while IFS= read -r snapshot; do
        if [[ -z "$snapshot" ]]; then
            continue
        fi

        creation_time=$(
            "${virsh_command[@]}" snapshot-dumpxml \
                --domain "$hostname" \
                --snapshotname "$snapshot" \
                --xpath '/domainsnapshot/creationTime/text()'
        ) || return

        if [[ ! "$creation_time" =~ ^[0-9]+$ ]]; then
            printf 'Invalid creation time for snapshot: %s\n' "$snapshot" >&2
            return 1
        fi

        if (( creation_time > latest_creation_time )); then
            latest_creation_time="$creation_time"
            latest_snapshot="$snapshot"
        fi
    done <<< "$snapshot_names"

    # Restore the snapshot and leave the VM running.
    # Changes made since this snapshot will be discarded.
    printf 'Restoring %s to snapshot %s and starting it\n' \
        "$hostname" "$latest_snapshot"

    "${virsh_command[@]}" snapshot-revert \
        --domain "$hostname" \
        --snapshotname "$latest_snapshot" \
        --running
}

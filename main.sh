#!/bin/bash

ZATHURA_CONFIG_DIR="$HOME/.config/zathura/"

# set to 1 for the window manager you use
DWM=1
HYPRLAND=0

move_on_stack () {
    # moves a process on the stack
    echo "Please implement me hello (move_on_stack)"
}

dwm_discard_windows_on_other_workspaces () {
    while IFS= read -r line; do
        read -ra words <<< "$line"
        if [[ "${words[3]}" -lt 0 ]]; then
            # printf "remove $line \n"
            :
        else
            printf "$line \n"
        fi
    done
}

put_window_on_master () {
    count=1
    for arg in "$@"; do
        if [[ count -eq $# ]]; then
            return 0
        fi
        xdotool windowactivate --sync $arg
        xdotool key --window "$arg" Alt+Return
        ((count++))
    done
}

get_stack_location_dwm () {
    # input: pid, and the wmctrl output with only the windows from the current tag
    # output: int that specifies the stack location, 0 meaning on top
    local lines=()
    local locx=0
    local locy=0
    local windows_in_front=()
    while IFS= read -r line; do
        lines+=("$line")
    done

    for line in "${lines[@]}"; do
        read -ra words <<< "$line"
        if [[ "${words[2]}" = $1 ]]; then
            locx="${words[3]}"
            locy="${words[4]}"
        fi
    done
    # TODO sort lines by geometry to keep order of other windows
    count=0
    for line in "${lines[@]}"; do
        read -ra words <<< "$line"
        other_locx=$(echo ${words[3]} | xargs)
        locx=$(echo $locx | xargs)
        if [[ "$other_locx" -lt "$locx" ]]; then
            ((count++))
            printf "${words[0]}\n"
        elif [[ "${words[3]}" = $locx  && "${words[4]}" -lt $locy ]]; then
            ((count++))
            printf "${words[0]}\n"
        fi
    done
    echo $count
}

get_location () {
    echo "${@:$#}"
}

pid_in_output () {
    while IFS= read -r line; do
        read -ra words <<< "$line"
        if [[ "words[2]" = $1 ]]; then
            return 1
        fi
    done
    return 0
}
trap exit TERM
set -x
pids=$(pgrep zathura)
for pid in $pids; do
    # s|(-c[[:space:]]+)/home/[^[:space:]]+|\1$newval|"
    cmd=$(ps -p $pid -o cmd=)
    newcmd=$(echo "$cmd" | awk -v config_dir="$ZATHURA_CONFIG_DIR" -v arg1="$1" '{gsub(/-c[[:space:]]+\/home\/[^[:space:]]+/, "-c " config_dir arg1); print}')
    newcmd=$(echo $newcmd | sed -E "s|(-x )(.*)|\1\"\2\"|")
    echo $newcmd > /home/air_berlin/OtherPrograms/zathura-scripts/log
    if [[ $DWM = 1 ]]; then
        wmctrl_output=$(wmctrl -l -p -G | dwm_discard_windows_on_other_workspaces)
        if [[ $(echo $wmctrl_output | pid_in_output $pid) = 0 ]]; then
            continue
        fi
        # loc includes the windows that should be moved in front of zathura again
        loc=$(echo "$wmctrl_output" | get_stack_location_dwm $pid)
        location=$(get_location $loc)
        echo $location
        active_window=$(xdotool getactivewindow)
    fi
    kill $pid
    eval $newcmd &
    if [[ $DWM = 1 ]]; then
        sleep 0.2  # hope zathura created a window by now
        echo $loc
        put_window_on_master $loc
        xdotool windowactivate $active_window
    fi
done

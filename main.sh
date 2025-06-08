#!/bin/bash

ZATHURA_CONFIG_DIR="$HOME/.config/zathura/"
HYPRLAND_JSON_FILE="$ZATHURA_CONFIG_DIR/hypr.json"

# set to 1 for the window manager you use
DWM=0
HYPRLAND=1

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


pids=$(pgrep zathura)
for pid in $pids; do
    # replace the -c option and potentially reapply quotes around -x option
    cmd=$(ps -p $pid -o cmd=)
    newcmd=$(echo "$cmd" | awk -v config_dir="$ZATHURA_CONFIG_DIR" -v arg1="$1" '{gsub(/-c[[:space:]]+\/home\/[^[:space:]]+/, "-c " config_dir arg1); print}')
    newcmd=$(echo $newcmd | sed -E "s|(-x )(.*)|\1\"\2\"|")

    if [[ $DWM = 1 ]]; then
        wmctrl_output=$(wmctrl -l -p -G | dwm_discard_windows_on_other_workspaces)
        if [[ $(echo $wmctrl_output | pid_in_output $pid) = 0 ]]; then
            continue
        fi
        # loc includes the windows that should be moved in front of zathura again
        # maybe to much magic but you'll figure it out if you want to ;)
        loc=$(echo "$wmctrl_output" | get_stack_location_dwm $pid)
        location=$(get_location $loc)
        echo $location
        active_window=$(xdotool getactivewindow)
    elif [[ $HYPRLAND = 1 ]]; then
        hyprctl clients -j > $HYPRLAND_JSON_FILE
        active_window=$(hyprctl activewindow -j | jq -r ".address")
    fi

    kill $pid
    eval $newcmd &
    echo $newcmd

    if [[ $DWM = 1 ]]; then
        sleep 0.2  # hope zathura created a window by now
        echo $loc
        put_window_on_master $loc # this should not be quoted
        xdotool windowactivate $active_window
    elif [[ $HYPRLAND = 1 ]]; then
        sleep 0.2 # hope zathura created a window by now
        length=$(jq '. | length' $HYPRLAND_JSON_FILE)
        for ((i=0; i<length; i++)); do
            if [[ $(jq -r ".[$i].pid" $HYPRLAND_JSON_FILE) = $pid ]]; then
                hyprctl dispatch movetoworkspace "$(jq -r ".[$i].workspace.id" $HYPRLAND_JSON_FILE)"
                for (( j=0; j<4; j++ )); do
                    xloc_wanted=$(jq -r ".[$i].at" $HYPRLAND_JSON_FILE | tr -d '[]\n' | cut -d',' -f1)
                    xloc_current=$(hyprctl activewindow -j | jq -r ".at" | tr -d '[]\n' | cut -d',' -f1)
                    yloc_wanted=$(jq -r ".[$i].at" $HYPRLAND_JSON_FILE | tr -d '[]\n' | cut -d',' -f2)
                    yloc_current=$(hyprctl activewindow -j | jq -r ".at" | tr -d '[]\n' | cut -d',' -f2)
                    if [[ $xloc_wanted -lt $xloc_current ]]; then
                        hyprctl dispatch movewindow l
                    elif [[ $xloc_wanted -gt $xloc_current ]]; then
                        hyprctl dispatch movewindow r
                    elif [[ $yloc_wanted -lt $yloc_current ]]; then
                        hyprctl dispatch movewindow u
                    elif [[ $yloc_wanted -gt $yloc_current ]]; then
                        hyprctl dispatch movewindow d
                    else
                        break
                    fi
                done
                hyprctl dispatch setprop activewindow at "$(jq -r ".[$i].at" $HYPRLAND_JSON_FILE | tr -d '[]')"
                # hyprctl dispatch resizewindow "$()"
            fi
        done
        hyprctl dispatch focuswindow address:$active_window
    fi
done

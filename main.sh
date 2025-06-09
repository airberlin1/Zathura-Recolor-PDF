#!/bin/bash

ZATHURA_CONFIG_DIR="$HOME/.config/zathura/"
HYPRLAND_JSON_FILE="$ZATHURA_CONFIG_DIR/hypr.json"

# set to 1 for the window manager you use
DWM=1 # recolor zathura windows on current tag
HYPRLAND=0 # recolor all zathura windows


dwm_discard_windows_on_other_workspaces () {
    # removes windows with other tags to not get confused when
    # determening the position on the stack
    while IFS= read -r line; do
        read -ra words <<< "$line"
        # windows with other tags have a negative x location
        if [[ "${words[3]}" -lt 0 ]]; then
            :
        else
            printf "%s\n" "$line"
        fi
    done
}

dwm_get_stack_location () {
    # input: pid as $1,
    # wmctrl output with only the windows from the current tag as rest

    local lines=()
    local locx=0
    local locy=0

    line_amount=0
    while IFS= read -r line; do
        lines+=("$line")
        ((line_amount++))
    done

    for line in "${lines[@]}"; do
        read -ra words <<< "$line"
        if [[ "${words[2]}" -eq "$1" ]]; then
            locx="${words[3]}"
            locy="${words[4]}"
        fi
    done

    # sort the windows in such a way that the bottom left comes first
    # important for preserving the order of the other windows
    # when pushing the new zathura window back in
    for (( i=0; i<line_amount - 1; i++ )); do
        for (( j=0; j<line_amount - 1; j++)); do
            read -ra words1 <<< "${lines[j]}"
            read -ra words2 <<< "${lines[j+1]}"
            if [[ "${words2[3]}" -gt "${words1[3]}" ]]; then
                temp=${lines[$j]}
                lines[j]=${lines[$j+1]}
                lines[j+1]=$temp
            elif [[ "${words2[3]}" -eq "${words1[3]}" && "${words2[4]}" -gt "${words1[4]}" ]]; then
                temp=${lines[$j]}
                lines[j]=${lines[$j+1]}
                lines[j+1]=$temp
            fi
        done
    done

    # return the windows that are above or to the left of the old zathura window
    for line in "${lines[@]}"; do
        read -ra words <<< "$line"
        if [[ "${words[3]}" -lt "$locx" ]]; then
            printf "%s\n" "${words[0]}"
        elif [[ "${words[3]}" -eq "$locx"  && "${words[4]}" -lt "$locy" ]]; then
            printf "%s\n" "${words[0]}"
        fi
    done
}

dwm_pid_in_output () {
    # checks if a pid is on the current tag in dwm
    # will not be affected if it is not
    while IFS= read -r line; do
        read -ra words <<< "$line"
        if [[ "${words[2]}" -eq "$1" ]]; then
            return 1
        fi
    done
    return 0
}

dwm_put_window_on_master () {
    # moves all windows specified by their window id on top of master
    # this will cause all other windows to be pushed back
    for window in "$@"; do
        xdotool windowactivate --sync "$window"
        xdotool key --window "$window" Alt+Return
    done
}

hyprland_move_window_back () {
    # moves the newly created zathura window back
    # to the location of the original window
    # input: original pid
    #
    # this should in most cases work to get to top left corner back,
    # but could change the tiling of the other windows
    # I currently don't know a better way I care to implement
    length=$(jq '. | length' "$HYPRLAND_JSON_FILE")
    for ((i=0; i<length; i++)); do
        if [[ $(jq -r ".[$i].pid" "$HYPRLAND_JSON_FILE") = $1 ]]; then
            hyprctl dispatch movetoworkspace "$(jq -r ".[$i].workspace.id" "$HYPRLAND_JSON_FILE")"
            for (( j=0; j<6; j++ )); do
                xloc_wanted=$(jq -r ".[$i].at" "$HYPRLAND_JSON_FILE" | tr -d '[]\n' | cut -d',' -f1)
                xloc_current=$(hyprctl activewindow -j | jq -r ".at" | tr -d '[]\n' | cut -d',' -f1)
                yloc_wanted=$(jq -r ".[$i].at" "$HYPRLAND_JSON_FILE" | tr -d '[]\n' | cut -d',' -f2)
                yloc_current=$(hyprctl activewindow -j | jq -r ".at" | tr -d '[]\n' | cut -d',' -f2)
                if [[ $xloc_wanted -lt $xloc_current ]]; then
                    hyprctl dispatch movewindow l
                fi
                if [[ $xloc_wanted -gt $xloc_current ]]; then
                    hyprctl dispatch movewindow r
                fi
                if [[ $yloc_wanted -lt $yloc_current ]]; then
                    hyprctl dispatch movewindow u
                fi
                if [[ $yloc_wanted -gt $yloc_current ]]; then
                    hyprctl dispatch movewindow d
                fi
            done
        fi
    done
}

trap exit TERM


pids=$(pgrep zathura)
for pid in $pids; do
    # command zathura was started with
    cmd=$(ps -p "$pid" -o cmd=)
    # replace c option if c option was absolute path starting with /home
    cmd_c_replaced=$(echo "$cmd" | sed -e "s|-c[[:space:]]\+[^[:space:]]\+|-c ${ZATHURA_CONFIG_DIR}$1|g")
    # quote everything after -x. Might not always be desired in this way
    newcmd=$(echo "$cmd_c_replaced" | sed -E "s|(-x )(.*)|\1\"\2\"|")

    if [[ $DWM = 1 ]]; then
        wmctrl_output=$(wmctrl -l -p -G | dwm_discard_windows_on_other_workspaces)
        if [[ $(echo "$wmctrl_output" | dwm_pid_in_output $pid) = 0 ]]; then
            continue # zathura window is on another tag
        fi
        windows_on_top=$(echo "$wmctrl_output" | dwm_get_stack_location $pid)
        active_window=$(xdotool getactivewindow)
    elif [[ $HYPRLAND = 1 ]]; then
        hyprctl clients -j > "$HYPRLAND_JSON_FILE"
        active_window=$(hyprctl activewindow -j | jq -r ".address")
    fi

    kill "$pid"
    eval "$newcmd" &

    if [[ $DWM = 1 ]]; then
        sleep 0.2  # hope zathura created a window by now
        dwm_put_window_on_master $windows_on_top # input should not be quoted
        xdotool windowactivate "$active_window"
    elif [[ $HYPRLAND = 1 ]]; then
        sleep 0.2 # hope zathura created a window by now
        hyprland_move_window_back "$pid"
        hyprctl dispatch focuswindow "address:$active_window"
        rm "$HYPRLAND_JSON_FILE"
    fi
done

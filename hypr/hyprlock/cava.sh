#!/bin/bash
#
# Vertical Equalizer Visualizer (Dense Vertical Layout)
# -----------------------------------------------------
# This script generates a multi-row visualizer effect by outputting stacked lines
# of Pango-formatted characters. The animation is driven by the system clock
# to ensure smooth motion. If no music is playing, it rests on the bottom row.
#

player="spotify"
VIS_BARS=48          # Width (number of columns) - Increased for full width
MAX_HEIGHT=6         # Height (number of levels)
COLOR_ACTIVE="#${1}" # Yellow/Gold for active peak
COLOR_DIM="#${2}01"    # COMPLETELY TRANSPARENT
SPACE_CHAR=" "       # Character for spacing between columns

# Function to find the currently playing player
find_player() {
    local status
    status=$(playerctl -p "$player" status 2> /dev/null)
    if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
        echo "$player"
        return
    fi
    playerctl -l 2> /dev/null | head -n 1
}

generate_visualizer() {
    local current_player
    current_player=$(find_player)

    local status=""
    if [[ -n "$current_player" ]]; then
        status=$(playerctl -p "$current_player" status 2> /dev/null)
    fi

    # Cek apakah audio sedang diputar
    local is_playing=0
    if [[ "$status" == "Playing" ]]; then
        is_playing=1
    fi

    # Use high-res system time (milliseconds) for smooth, non-stuck animation
    local CURRENT_TIME_MS
    CURRENT_TIME_MS=$(date +%s%3N | cut -c-13)

    # MASTER_PHASE controls the speed of the wave motion (Lower divisor = faster)
    local MASTER_PHASE=$((CURRENT_TIME_MS / 90))

    local heights=()
    # Calculate height for each bar using an increased factor (31) to prevent short horizontal repetition
    for ((i = 0; i < VIS_BARS; i++)); do
        if (( is_playing == 0 )); then
            # Jika tidak ada lagu / paused, paksa tinggi bar menjadi 1 (hanya baris paling bawah)
            heights[i]=1
        else
            # 1. Base wave (ombak dasar yang bergeser halus)
            local wave=$(((i * 27 + MASTER_PHASE) % (MAX_HEIGHT * 2)))
            if ((wave > MAX_HEIGHT)); then
                wave=$((MAX_HEIGHT * 2 - wave))
            fi

            # 2. Tambahkan noise acak (efek pantulan audio EQ)
            local noise=$((RANDOM % (MAX_HEIGHT / 2 + 2)))
            
            # 3. Gabungkan wave dasar dengan noise
            local h=$(( (wave / 2) + noise ))

            # Pastikan tinggi tidak melebihi batas layar visualizer
            if ((h < 1)); then h=1; fi
            if ((h > MAX_HEIGHT)); then h=$MAX_HEIGHT; fi

            heights[i]=$h
        fi
    done

    # Draw stacked bars row by row (from top to bottom)
    for ((row = MAX_HEIGHT; row > 0; row--)); do
        local line=""
        for ((i = 0; i < VIS_BARS; i++)); do
            # Check if the calculated height for this bar is greater than or equal to the current row number
            if ((heights[i] >= row)); then
                # Bar is active at this row level (use active color)
                line+="<span foreground='$COLOR_ACTIVE'></span>"
            else
                # Bar is below this row level (use dim background color)
                line+="<span foreground='$COLOR_DIM'></span>"
            fi
            # Add a small space to create separation between columns (adjust this spacing for visual preference)
            line+="$SPACE_CHAR"
        done
        # Print the entire row followed by a newline (if running in an environment that handles newlines)
        echo "$line"
    done
}

generate_visualizer

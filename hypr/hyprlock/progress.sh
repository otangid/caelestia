#!/bin/bash

# Configuration
player="spotify"
BAR_LENGTH=32
COLOR_PLAYED="#${1}"
COLOR_REMAINING="#${2}"
SPACE_CHAR="━"
STATIC_HANDLE=""

# Cache files
CACHE_FILE="/tmp/hyprlock_mpris_pos.cache"
CACHE_ID_FILE="/tmp/hyprlock_mpris_id.cache"

# Fungsi untuk menampilkan bar idle (0:00 / 0:00)
print_idle_bar() {
    local bar_remaining=""
    for ((i = 1; i <= BAR_LENGTH; i++)); do
        bar_remaining+="$SPACE_CHAR"
    done
    echo "<span foreground=\"#ffffff\">$STATIC_HANDLE</span><span foreground=\"$COLOR_REMAINING\">$bar_remaining</span> 0:00 / 0:00"
}

find_player() {
    status=$(playerctl -p "$player" status 2> /dev/null)
    if [[ "$status" == "Playing" || "$status" == "Paused" ]]; then
        echo "$player"
        return 0
    fi

    local active_player=$(playerctl -l 2> /dev/null | head -n 1)
    if [ -n "$active_player" ]; then
        echo "$active_player"
    fi
}

get_metadata() {
    local current_player=$1
    local key=$2
    playerctl -p "$current_player" metadata "$key" 2> /dev/null
}

get_status_and_position() {
    local current_player=$(find_player)

    if [ -z "$current_player" ]; then
        print_idle_bar
        rm -f "$CACHE_FILE" "$CACHE_ID_FILE"
        exit 0
    fi

    local status=$(playerctl -p "$current_player" status 2> /dev/null)

    if [[ "$status" != "Playing" && "$status" != "Paused" ]]; then
        print_idle_bar
        rm -f "$CACHE_FILE" "$CACHE_ID_FILE"
        exit 0
    fi

    pos_raw=$(playerctl -p "$current_player" position 2> /dev/null | awk '{printf "%.0f", $1 * 1000000}' || echo 0)
    length_raw=$(get_metadata "$current_player" "mpris:length" | cut -d '.' -f1 || echo 0)
    current_track_id=$(get_metadata "$current_player" "mpris:trackid")

    if [[ "$length_raw" -le 0 ]]; then
        print_idle_bar
        rm -f "$CACHE_FILE" "$CACHE_ID_FILE"
        exit 0
    fi

    local last_track_id=$(cat "$CACHE_ID_FILE" 2> /dev/null || echo "")
    local last_cached_pos=$([ -f "$CACHE_FILE" ] && cat "$CACHE_FILE" || echo 0)

    if [[ "$current_track_id" != "$last_track_id" ]]; then
        pos_to_use=$pos_raw
    else
        if [[ "$status" == "Playing" ]]; then
            # PERBAIKAN LOGIKA: Tangani saat posisi melompat mundur (rewind/reset awal lagu)
            if (( pos_raw < last_cached_pos - 2000000 )); then
                pos_to_use=$pos_raw
            # Tangani saat posisi melompat maju drastis (forward)
            elif (( pos_raw > last_cached_pos + 2000000 )); then
                pos_to_use=$pos_raw
            # Jika playerctl stuck (tidak update posisi), asumsikan maju 1 detik
            elif (( pos_raw == last_cached_pos && last_cached_pos > 0 )); then
                pos_to_use=$((last_cached_pos + 1000000))
            else
                pos_to_use=$pos_raw
            fi
        else
            pos_to_use=$pos_raw
        fi
    fi

    if ((pos_to_use > length_raw)); then
        pos_to_use=$length_raw
        rm -f "$CACHE_FILE"
    fi

    echo "$current_track_id" > "$CACHE_ID_FILE"
    echo "$pos_to_use" > "$CACHE_FILE"

    local pos_sec=$((pos_to_use / 1000000))
    local length_sec=$((length_raw / 1000000))

    progress=$((pos_to_use * BAR_LENGTH / length_raw))

    if ((progress > BAR_LENGTH)); then
        progress=$BAR_LENGTH
    fi

    if [[ "$status" == "Playing" && "$progress" -eq 0 && "$BAR_LENGTH" -gt 0 ]]; then
        progress=1
    fi

    bar_played=""
    for ((i = 0; i < progress; i++)); do
        bar_played+="$SPACE_CHAR"
    done

    bar_remaining=""
    for ((i = progress + 1; i <= BAR_LENGTH; i++)); do
        bar_remaining+="$SPACE_CHAR"
    done

    if ((progress == BAR_LENGTH)); then
        final_bar="<span foreground=\"$COLOR_PLAYED\">${bar_played}${SPACE_CHAR}</span>"
    else
        final_bar="<span foreground=\"$COLOR_PLAYED\">$bar_played$STATIC_HANDLE</span><span foreground=\"$COLOR_REMAINING\">$bar_remaining</span>"
    fi

    format_time() {
        local m=$(($1 / 60))
        local s=$(($1 % 60))
        printf "%d:%02d" "$m" "$s"
    }

    pos_fmt=$(format_time "$pos_sec")
    len_fmt=$(format_time "$length_sec")

    echo "$pos_fmt $final_bar $len_fmt"
}

get_status_and_position


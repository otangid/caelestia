#!/bin/bash

# 1. Tentukan path gambar bawaan Anda di sini
FALLBACK_IMG="~/.config/hypr/hyprlock/cover.png"

# Ambil URL album art
ART_URL=$(playerctl metadata mpris:artUrl 2> /dev/null)

# Jika tidak ada lagu/art, gunakan gambar bawaan
if [[ -z "$ART_URL" ]]; then
    # Pastikan file fallback ada sebelum disalin
    if [[ -f "$FALLBACK_IMG" ]]; then
        cp "$FALLBACK_IMG" /tmp/cover.png
    fi
    echo "/tmp/cover.png"
    exit 0
fi

# Unduh jika berupa URL HTTP (misal: Spotify web)
if [[ "$ART_URL" == http* ]]; then
    curl -s "$ART_URL" -o /tmp/cover.png
# Hapus prefix file:// jika berupa file lokal (misal: MPD / VLC)
elif [[ "$ART_URL" == file://* ]]; then
    cp "${ART_URL#file://}" /tmp/cover.png
fi

# Cetak path untuk hyprlock
echo "/tmp/cover.png"

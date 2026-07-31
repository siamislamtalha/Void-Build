#!/bin/bash

# Void Music Uninstall Cleanup Script for Linux
# This script cleans up all Void Music data during uninstall

echo "Void Music Uninstall Cleanup"
echo "============================"

# Get home directory
HOME_DIR="$HOME"

# Define Void Music app data paths for Linux
# XDG Data Home
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME_DIR/.local/share}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME_DIR/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME_DIR/.cache}"

VOID_MUSIC_PATHS=(
    "$XDG_DATA_HOME/voidmusic"
    "$XDG_DATA_HOME/com.example.voidmusic"
    "$XDG_CONFIG_HOME/voidmusic"
    "$XDG_CONFIG_HOME/com.example.voidmusic"
    "$XDG_CACHE_HOME/voidmusic"
    "$XDG_CACHE_HOME/com.example.voidmusic"
    "$HOME_DIR/.voidmusic"
)

# Clean up app data directories
for path in "${VOID_MUSIC_PATHS[@]}"; do
    if [ -e "$path" ]; then
        echo "Removing: $path"
        rm -rf "$path"
        if [ $? -eq 0 ]; then
            echo "Successfully removed: $path"
        else
            echo "Failed to remove: $path"
        fi
    else
        echo "Path not found (skipping): $path"
    fi
done

# Clean up desktop entry
DESKTOP_ENTRY="$HOME_DIR/.local/share/applications/voidmusic.desktop"
if [ -e "$DESKTOP_ENTRY" ]; then
    echo "Removing desktop entry: $DESKTOP_ENTRY"
    rm -f "$DESKTOP_ENTRY"
fi

# Clean up icons
ICON_DIR="$HOME_DIR/.local/share/icons"
if [ -d "$ICON_DIR" ]; then
    echo "Removing Void Music icons from: $ICON_DIR"
    find "$ICON_DIR" -name "*voidmusic*" -delete 2>/dev/null
fi

echo "Cleanup completed!"

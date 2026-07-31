#!/bin/bash

# Void Music Uninstall Cleanup Script for macOS
# This script cleans up all Void Music data during uninstall

echo "Void Music Uninstall Cleanup"
echo "============================"

# Get home directory
HOME_DIR="$HOME"

# Define Void Music app data paths for macOS
VOID_MUSIC_PATHS=(
    "$HOME_DIR/Library/Application Support/voidmusic"
    "$HOME_DIR/Library/Application Support/com.example.voidmusic"
    "$HOME_DIR/Library/Caches/voidmusic"
    "$HOME_DIR/Library/Caches/com.example.voidmusic"
    "$HOME_DIR/Library/Preferences/voidmusic.plist"
    "$HOME_DIR/Library/Preferences/com.example.voidmusic.plist"
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

echo "Cleanup completed!"

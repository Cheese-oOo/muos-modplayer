#!/bin/sh
# HELP: IPTVViwer
# ICON: iptvviewer

# Application icon should be installed in themes to be used in the Application menu.
# theme/glyph/muxapp/iptvviewer.png

. /opt/muos/script/var/func.sh

# Define Paths
LOVE_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/ModPlayer"
GPTOKEYB="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb/gptokeyb2"

> "$LOVE_DIR/log.txt" && exec > >(tee "$LOVE_DIR/log.txt") 2>&1

# Export Environment Variables
export SDL_GAMECONTROLLERCONFIG_FILE="/usr/lib/gamecontrollerdb.txt"

# Launch Application
cd "$LOVE_DIR" || exit
SET_VAR "system" "foreground_process" "love"
export LD_LIBRARY_PATH="$LOVE_DIR/libs:$LD_LIBRARY_PATH"

$GPTOKEYB "love" -c "ModPlayer.gptk" &
./love ./

# Cleanup
kill -9 "$(pidof gptokeyb2)"

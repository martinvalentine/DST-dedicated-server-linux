#!/bin/bash
# Quick start script - Opens DST server in separate terminals

SERVER_DIR="$HOME/steamapps/DST"

# Detect terminal
if command -v kitty &>/dev/null; then
    echo "Starting DST server in Kitty..."
    kitty --title="DST Master Shard" bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash" &
    sleep 3
    kitty --title="DST Caves Shard" bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash" &
elif command -v gnome-terminal &>/dev/null; then
    echo "Starting DST server in GNOME Terminal..."
    gnome-terminal --title="DST Master Shard" -- bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash" &
    sleep 3
    gnome-terminal --title="DST Caves Shard" -- bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash" &
elif command -v konsole &>/dev/null; then
    echo "Starting DST server in Konsole..."
    konsole --title "DST Master Shard" -e bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash" &
    sleep 3
    konsole --title "DST Caves Shard" -e bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash" &
elif command -v xfce4-terminal &>/dev/null; then
    echo "Starting DST server in XFCE Terminal..."
    xfce4-terminal --title="DST Master Shard" -e "bash -c 'cd $SERVER_DIR/bin64 && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash'" &
    sleep 3
    xfce4-terminal --title="DST Caves Shard" -e "bash -c 'cd $SERVER_DIR/bin64 && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash'" &
elif command -v xterm &>/dev/null; then
    echo "Starting DST server in XTerm..."
    xterm -title "DST Master Shard" -e bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash" &
    sleep 3
    xterm -title "DST Caves Shard" -e bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash" &
else
    echo "Error: No supported terminal emulator found!"
    echo "Please install: kitty, gnome-terminal, konsole, xfce4-terminal, or xterm"
    exit 1
fi

echo "✓ Server started in separate terminal windows!"
echo "  - Master Shard (Overworld)"
echo "  - Caves Shard (Underground)"

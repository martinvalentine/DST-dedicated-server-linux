#!/bin/bash
# dst-server-manager.sh - Manage DST Dedicated Server

# Get script directory for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
readonly SERVER_DIR="$HOME/steamapps/DST"
readonly DEDI_SERVER_DIR="$HOME/.klei/DoNotStarveTogether/MyDediServer"

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}→${NC} $1"; }

# Function to start server in separate terminals
start_server_terminals() {
    print_info "Detecting terminal emulator..."
    
    local term_cmd=""
    if command -v kitty &>/dev/null; then
        term_cmd="kitty"
    elif command -v gnome-terminal &>/dev/null; then
        term_cmd="gnome-terminal"
    elif command -v konsole &>/dev/null; then
        term_cmd="konsole"
    elif command -v xfce4-terminal &>/dev/null; then
        term_cmd="xfce4-terminal"
    elif command -v xterm &>/dev/null; then
        term_cmd="xterm"
    else
        print_error "No supported terminal emulator found!"
        echo "Please install: kitty, gnome-terminal, konsole, xfce4-terminal, or xterm"
        exit 1
    fi
    
    print_info "Using terminal: $term_cmd"
    
    # Launch Master in new terminal
    print_info "Opening Master shard in new terminal..."
    case "$term_cmd" in
        kitty)
            kitty --title="DST Master Shard" bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash" &
            ;;
        gnome-terminal)
            gnome-terminal --title="DST Master Shard" -- bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash" &
            ;;
        konsole)
            konsole --title "DST Master Shard" -e bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash" &
            ;;
        xfce4-terminal)
            xfce4-terminal --title="DST Master Shard" -e "bash -c 'cd $SERVER_DIR/bin64 && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash'" &
            ;;
        xterm)
            xterm -title "DST Master Shard" -e bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master; exec bash" &
            ;;
    esac
    
    sleep 3
    
    # Launch Caves in new terminal
    print_info "Opening Caves shard in new terminal..."
    case "$term_cmd" in
        kitty)
            kitty --title="DST Caves Shard" bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash" &
            ;;
        gnome-terminal)
            gnome-terminal --title="DST Caves Shard" -- bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash" &
            ;;
        konsole)
            konsole --title "DST Caves Shard" -e bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash" &
            ;;
        xfce4-terminal)
            xfce4-terminal --title="DST Caves Shard" -e "bash -c 'cd $SERVER_DIR/bin64 && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash'" &
            ;;
        xterm)
            xterm -title "DST Caves Shard" -e bash -c "cd '$SERVER_DIR/bin64' && ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves; exec bash" &
            ;;
    esac
    
    echo
    print_success "Server started in separate terminal windows!"
    echo
    print_info "Two new terminal windows have been opened:"
    echo "  - Master Shard (Overworld)"
    echo "  - Caves Shard (Underground)"
    echo
    print_info "You can see the server output in each window."
    print_info "Close the terminal windows or press Ctrl+C in them to stop the servers."
}

# Function to start server in background
start_server_background() {
    cd "$SERVER_DIR/bin64" || {
        print_error "Failed to change to server directory"
        exit 1
    }
    
    print_info "Starting Master shard in background..."
    ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master &
    local master_pid=$!
    
    sleep 3
    
    print_info "Starting Caves shard in background..."
    ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves &
    local caves_pid=$!
    
    cd - >/dev/null
    
    echo
    print_success "Server started in background!"
    echo
    print_info "Process Information:"
    echo "  Master PID: $master_pid"
    echo "  Caves PID: $caves_pid"
    echo
    print_info "Log Files:"
    echo "  Master: $DEDI_SERVER_DIR/Master/server_log.txt"
    echo "  Caves: $DEDI_SERVER_DIR/Caves/server_log.txt"
}

# Function to stop server
stop_server() {
    print_info "Stopping DST server..."
    
    local master_pid=$(pgrep -f "dontstarve.*Master")
    local caves_pid=$(pgrep -f "dontstarve.*Caves")
    
    if [ -n "$master_pid" ]; then
        print_info "Stopping Master shard (PID: $master_pid)..."
        kill $master_pid
    else
        print_info "Master shard not running"
    fi
    
    if [ -n "$caves_pid" ]; then
        print_info "Stopping Caves shard (PID: $caves_pid)..."
        kill $caves_pid
    else
        print_info "Caves shard not running"
    fi
    
    if [ -z "$master_pid" ] && [ -z "$caves_pid" ]; then
        print_info "No server processes found"
        return 0
    fi
    
    print_info "Waiting for servers to save and exit..."
    sleep 5
    
    # Check if still running and force kill if needed
    if pgrep -f dontstarve_dedicated_server > /dev/null; then
        print_info "Servers still running, forcing shutdown..."
        pkill -9 -f dontstarve_dedicated_server
    fi
    
    print_success "DST server stopped"
}

# Function to fix Steam Workshop directories
fix_workshop() {
    print_info "Fixing Steam Workshop directory structure..."
    
    local steam_content_dir="$SERVER_DIR/steamapps"
    local workshop_dir="$steam_content_dir/workshop"
    local dst_workshop_id="322330"  # Workshop uses the game's app ID
    local dst_app_id="343050"
    
    # Create required directories
    local workshop_dirs=(
        "$steam_content_dir"
        "$workshop_dir"
        "$workshop_dir/content"
        "$workshop_dir/content/$dst_workshop_id"
        "$workshop_dir/downloads"
        "$workshop_dir/temp"
        "$steam_content_dir/downloading"
        "$steam_content_dir/temp"
    )
    
    for dir in "${workshop_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if mkdir -p "$dir"; then
                print_success "Created: $dir"
            else
                print_error "Failed to create: $dir"
            fi
        else
            print_info "Exists: $dir"
        fi
    done
    
    # Create workshop manifest file
    local acf_file="$workshop_dir/appworkshop_$dst_workshop_id.acf"
    if [[ ! -f "$acf_file" ]]; then
        cat > "$acf_file" << EOF
"AppWorkshop"
{
	"appid"		"$dst_workshop_id"
	"SizeOnDisk"		"0"
	"NeedsUpdate"		"0"
	"NeedsDownload"		"0"
	"TimeLastUpdated"		"0"
	"TimeLastAppRan"		"0"
	"WorkshopItemsInstalled"
	{
	}
	"WorkshopItemDetails"
	{
	}
}
EOF
        print_success "Created workshop manifest"
    fi
    
    # Create library folders manifest
    local library_file="$steam_content_dir/libraryfolders.vdf"
    if [[ ! -f "$library_file" ]]; then
        cat > "$library_file" << EOF
"libraryfolders"
{
	"0"
	{
		"path"		"$SERVER_DIR"
		"label"		""
		"contentid"		"0"
		"totalsize"		"0"
		"update_clean_bytes_tally"		"0"
		"time_last_update_corruption"		"0"
		"apps"
		{
			"$dst_app_id"		"0"
		}
	}
}
EOF
        print_success "Created library manifest"
    fi
    
    echo
    print_success "Steam Workshop directories are ready!"
    print_info "Restart the server for changes to take effect."
}

# Function to check server status
status_server() {
    local master_pid=$(pgrep -f "dontstarve.*Master")
    local caves_pid=$(pgrep -f "dontstarve.*Caves")
    
    echo
    echo "DST Server Status:"
    echo "=================="
    
    if [ -n "$master_pid" ]; then
        print_success "Master shard: Running (PID: $master_pid)"
    else
        print_error "Master shard: Not running"
    fi
    
    if [ -n "$caves_pid" ]; then
        print_success "Caves shard: Running (PID: $caves_pid)"
    else
        print_error "Caves shard: Not running"
    fi
    
    echo
    
    if [ -n "$master_pid" ] || [ -n "$caves_pid" ]; then
        print_info "Log Files:"
        echo "  Master: $DEDI_SERVER_DIR/Master/server_log.txt"
        echo "  Caves: $DEDI_SERVER_DIR/Caves/server_log.txt"
    fi
}

# Main menu
show_menu() {
    echo
    echo "╔════════════════════════════════════════╗"
    echo "║   DST Dedicated Server Manager         ║"
    echo "╚════════════════════════════════════════╝"
    echo
    echo "1) Start server (separate terminals)"
    echo "2) Start server (background)"
    echo "3) Stop server"
    echo "4) Server status"
    echo "5) View Master log (tail)"
    echo "6) View Caves log (tail)"
    echo "7) Fix Workshop mod downloads"
    echo "8) Exit"
    echo
}

# Main loop
while true; do
    show_menu
    read -rp "Enter choice [1-8]: " choice
    
    case "$choice" in
        1)
            start_server_terminals
            ;;
        2)
            start_server_background
            ;;
        3)
            stop_server
            ;;
        4)
            status_server
            ;;
        5)
            if [ -f "$DEDI_SERVER_DIR/Master/server_log.txt" ]; then
                tail -f "$DEDI_SERVER_DIR/Master/server_log.txt"
            else
                print_error "Master log file not found"
            fi
            ;;
        6)
            if [ -f "$DEDI_SERVER_DIR/Caves/server_log.txt" ]; then
                tail -f "$DEDI_SERVER_DIR/Caves/server_log.txt"
            else
                print_error "Caves log file not found"
            fi
            ;;
        7)
            fix_workshop
            ;;
        8)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    echo
    read -rp "Press Enter to continue..."
done

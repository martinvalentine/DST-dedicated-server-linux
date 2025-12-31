#!/bin/bash
# dst-server-setup.sh - DST Dedicated Server Setup Wizard for Arch Linux
# This wizard guides users through 8 sequential steps to set up a Don't Starve Together dedicated server

set -e

# ============================================================================
# Configuration Variables
# ============================================================================

readonly DST_APP_ID="343050"
readonly STEAMCMD_AUR="https://aur.archlinux.org/steamcmd.git"
readonly KLEI_TOKEN_URL="https://accounts.klei.com/account/game/servers?game=DontStarveTogether"

# Paths (using $HOME for portability)
readonly SERVER_DIR="$HOME/steamapps/DST"
readonly KLEI_DIR="$HOME/.klei/DoNotStarveTogether"
readonly DEDI_SERVER_DIR="$KLEI_DIR/MyDediServer"
readonly SERVER_MODS_DIR="$SERVER_DIR/mods"

# Total number of steps in the wizard
readonly TOTAL_STEPS=8

# ============================================================================
# ANSI Color Codes
# ============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# ============================================================================
# Color Output Functions
# ============================================================================

# Print success message with green checkmark
# Usage: print_success "message"
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Print error message with red X
# Usage: print_error "message"
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Print warning message with yellow exclamation
# Usage: print_warning "message"
print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

# Print info message with blue arrow
# Usage: print_info "message"
print_info() {
    echo -e "${BLUE}→${NC} $1"
}

# Print step header with step number and total (e.g., "[1/8] Step Title")
# Usage: print_step <step_number> "Step Title"
print_step() {
    local step_num=$1
    local step_title=$2
    echo -e "\n${BOLD}${CYAN}[${step_num}/${TOTAL_STEPS}]${NC} ${BOLD}${step_title}${NC}"
}

# ============================================================================
# User Input Functions
# ============================================================================

# Yes/No confirmation prompt
# Usage: confirm "Question?" && echo "yes" || echo "no"
# Returns: 0 for yes, 1 for no
confirm() {
    local prompt="$1"
    local response
    
    # Check if running in non-interactive mode (for testing)
    # Use environment variable or check if stdin is not a terminal
    if [[ -n "${DST_TEST_MODE}" ]] || [[ ! -t 0 ]]; then
        echo "$prompt [y/n]: y"
        return 0
    fi
    
    while true; do
        read -rp "$prompt [y/n]: " response
        case "$response" in
            [yY]|[yY][eE][sS]) return 0 ;;
            [nN]|[nN][oO]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# Arrow key selection menu
# Usage: select_option "Option 1" "Option 2" "Option 3"
# Returns: Index of selected option (0-based) via return code
# Note: Selected index is also stored in SELECTED_INDEX variable
select_option() {
    local options=("$@")
    local selected=0
    local key
    local num_options=${#options[@]}
    
    # Return early if no options
    if [[ $num_options -eq 0 ]]; then
        return 0
    fi
    
    # Check if running in non-interactive mode (for testing)
    # Use environment variable or check if stdin is not a terminal
    if [[ -n "${DST_TEST_MODE}" ]] || [[ ! -t 0 ]]; then
        echo -e "  ${GREEN}▶${NC} ${options[0]}"
        SELECTED_INDEX=0
        return 0
    fi
    
    # Hide cursor
    tput civis 2>/dev/null || true
    
    # Ensure cursor is restored on exit
    trap 'tput cnorm 2>/dev/null || true' RETURN
    
    while true; do
        # Display options
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${GREEN}▶${NC} ${options[$i]}"
            else
                echo "    ${options[$i]}"
            fi
        done
        
        # Read key input
        read -rsn1 key
        
        # Handle arrow keys (they send escape sequences)
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 key
            case "$key" in
                '[A') # Up arrow
                    ((selected > 0)) && ((selected--))
                    ;;
                '[B') # Down arrow
                    ((selected < num_options - 1)) && ((selected++))
                    ;;
            esac
        elif [[ "$key" == '' ]]; then
            # Enter key pressed
            break
        fi
        
        # Move cursor up to redraw options
        tput cuu "$num_options" 2>/dev/null || true
    done
    
    # Restore cursor
    tput cnorm 2>/dev/null || true
    
    # Store selected index in variable for easy access
    SELECTED_INDEX=$selected
    return $selected
}

# ============================================================================
# Step Functions
# ============================================================================

# Step 1: Check Dependencies
# Verifies all required packages are installed on the system
# Returns: 0 if all dependencies present, 1 if any missing
step_check_dependencies() {
    print_step 1 "Checking Dependencies"
    
    # Required dependencies for DST dedicated server setup
    local deps=("git" "base-devel" "lib32-gcc-libs" "lib32-glibc")
    local missing=()
    
    # Check each dependency
    for dep in "${deps[@]}"; do
        if pacman -Qi "$dep" &>/dev/null; then
            print_success "$dep is installed"
        else
            print_error "$dep is NOT installed"
            missing+=("$dep")
        fi
    done
    
    # Report results
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo
        print_error "Missing dependencies detected!"
        print_info "Install with: sudo pacman -S ${missing[*]}"
        return 1
    fi
    
    print_success "All dependencies satisfied"
    return 0
}

# Step 2: Install SteamCMD
# Installs SteamCMD from AUR if not already present
# Returns: 0 if SteamCMD is available, 1 on installation failure
step_install_steamcmd() {
    print_step 2 "Installing SteamCMD"
    
    # Check if SteamCMD is already installed
    if command -v steamcmd &>/dev/null; then
        print_success "SteamCMD is already installed"
        return 0
    fi
    
    print_info "SteamCMD not found. Installing from AUR..."
    
    # Create temporary directory for building
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Register for cleanup
    register_temp_dir "$temp_dir"
    
    # Clone SteamCMD from AUR
    print_info "Cloning SteamCMD from AUR..."
    if ! git clone "$STEAMCMD_AUR" "$temp_dir/steamcmd" 2>&1; then
        print_error "Failed to clone SteamCMD repository"
        return 1
    fi
    
    # Build and install with makepkg
    print_info "Building and installing SteamCMD..."
    cd "$temp_dir/steamcmd" || return 1
    
    if ! makepkg -si --noconfirm 2>&1; then
        print_error "Failed to build SteamCMD"
        cd - >/dev/null || true
        return 1
    fi
    
    cd - >/dev/null || true
    
    # Verify installation success
    if command -v steamcmd &>/dev/null; then
        print_success "SteamCMD installed successfully"
        return 0
    else
        print_error "SteamCMD installation verification failed"
        return 1
    fi
}

# Step 3: Install DST Dedicated Server
# Installs or updates the DST dedicated server using SteamCMD
# Returns: 0 if server is installed/updated successfully, 1 on failure
step_install_dst_server() {
    print_step 3 "Installing DST Dedicated Server"
    
    local server_exe="$SERVER_DIR/bin64/dontstarve_dedicated_server_nullrenderer_x64"
    
    # Check if server is already installed
    if [[ -f "$server_exe" ]]; then
        print_warning "DST server already installed at $SERVER_DIR"
        if confirm "Update existing installation?"; then
            print_info "Updating DST server..."
        else
            print_info "Skipping installation"
            return 0
        fi
    fi
    
    # Install/update DST server using SteamCMD
    print_info "Installing DST Dedicated Server (App ID: $DST_APP_ID)..."
    print_info "This may take several minutes depending on your connection..."
    
    # Run SteamCMD with required parameters
    # +force_install_dir: Set installation directory
    # +login anonymous: Login as anonymous user
    # +app_update: Download/update the app (343050 = DST Dedicated Server)
    # +quit: Exit SteamCMD after completion
    if ! steamcmd +force_install_dir "$SERVER_DIR" \
                  +login anonymous \
                  +app_update "$DST_APP_ID" \
                  +quit; then
        print_error "SteamCMD failed to install DST server"
        return 1
    fi
    
    # Verify server executable exists after installation
    if [[ -f "$server_exe" ]]; then
        print_success "DST server installed at $SERVER_DIR"
        return 0
    else
        print_error "DST server installation failed - executable not found"
        print_info "Expected: $server_exe"
        return 1
    fi
}

# Step 4: Setup Server Directory Structure
# Creates the required directory structure for DST server configuration
# Returns: 0 on success, 1 on failure
step_setup_directories() {
    print_step 4 "Setting Up Server Directory Structure"
    
    # Define directories to create in order
    local dirs=(
        "$HOME/.klei"
        "$KLEI_DIR"
        "$DEDI_SERVER_DIR"
    )
    
    # Create each directory, skipping if it already exists
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_info "Directory exists: $dir"
        else
            if mkdir -p "$dir"; then
                print_success "Created: $dir"
            else
                print_error "Failed to create directory: $dir"
                return 1
            fi
        fi
    done
    
    print_success "Directory structure ready"
    return 0
}

# Step 5: Cluster Discovery and Migration
# Scans for existing clusters and migrates the selected one to MyDediServer
# Returns: 0 if cluster migrated successfully, 1 if no clusters found or migration fails
step_migrate_cluster() {
    print_step 5 "Selecting and Migrating Cluster"
    
    print_info "Scanning for existing clusters..."
    
    local clusters=()
    local cluster_paths=()
    
    # Find Steam User ID directories (numeric directories only)
    # These are created by the game client when you create worlds
    for user_dir in "$KLEI_DIR"/[0-9]*; do
        # Skip if not a directory
        [[ -d "$user_dir" ]] || continue
        
        # Find Cluster_N directories within each user directory
        # Pattern: Cluster_[0-9]+ (e.g., Cluster_1, Cluster_2, etc.)
        for cluster_dir in "$user_dir"/Cluster_[0-9]*; do
            # Skip if not a directory
            [[ -d "$cluster_dir" ]] || continue
            
            # Validate cluster structure - must contain:
            # - cluster.ini (main configuration)
            # - Master/ (overworld shard)
            # - Caves/ (underground shard)
            if [[ -f "$cluster_dir/cluster.ini" ]] && \
               [[ -d "$cluster_dir/Master" ]] && \
               [[ -d "$cluster_dir/Caves" ]]; then
                # Extract cluster name and user ID for display
                local cluster_name=$(basename "$cluster_dir")
                local user_id=$(basename "$user_dir")
                
                # Add to selection list
                clusters+=("$cluster_name (User: $user_id)")
                cluster_paths+=("$cluster_dir")
            fi
        done
    done
    
    # Check if any valid clusters were found
    if [[ ${#clusters[@]} -eq 0 ]]; then
        print_error "No valid clusters found!"
        echo
        print_info "Please create a world in-game first:"
        print_info "  1. Launch Don't Starve Together"
        print_info "  2. Click 'Host Game'"
        print_info "  3. Create a new world"
        print_info "  4. Exit the game"
        print_info "  5. Run this wizard again"
        return 1
    fi
    
    # Display found clusters
    print_success "Found ${#clusters[@]} cluster(s)"
    echo
    print_info "Select a cluster to migrate:"
    echo
    
    # Use arrow key selection menu
    select_option "${clusters[@]}"
    local selected=$?
    local source_cluster="${cluster_paths[$selected]}"
    
    echo
    print_info "Migrating ${clusters[$selected]}..."
    print_info "Source: $source_cluster"
    print_info "Destination: $DEDI_SERVER_DIR"
    
    # Copy cluster contents to dedicated server directory
    # Using cp -r to recursively copy all files and subdirectories
    if ! cp -r "$source_cluster"/* "$DEDI_SERVER_DIR/"; then
        print_error "Failed to copy cluster data"
        print_info "Check permissions and disk space"
        return 1
    fi
    
    echo
    print_success "Cluster migrated successfully!"
    print_info "Configuration files copied to: $DEDI_SERVER_DIR"
    
    return 0
}

# Step 6: Configure Server Authentication
# Sets up the cluster token required for server authentication with Klei servers
# Returns: 0 if token is configured successfully, 1 on failure
step_configure_auth() {
    print_step 6 "Configuring Server Authentication"
    
    local token_file="$DEDI_SERVER_DIR/cluster_token.txt"
    
    # Check if token file already exists
    if [[ -f "$token_file" ]]; then
        print_info "Existing token found"
        if confirm "Keep existing token?"; then
            print_success "Using existing token"
            return 0
        else
            # User wants to replace the token
            print_info "Replacing existing token..."
            rm "$token_file"
        fi
    fi
    
    # Display instructions for obtaining a token
    echo
    print_info "You need a cluster token from Klei to authenticate your server"
    print_info "Get your token at:"
    echo -e "  ${CYAN}$KLEI_TOKEN_URL${NC}"
    echo
    print_info "Steps to get your token:"
    print_info "  1. Log in to your Klei account"
    print_info "  2. Click 'Generate Server Token'"
    print_info "  3. Copy the token"
    echo
    
    # Prompt user to enter token
    local token
    read -rp "Paste your cluster token: " token
    
    # Validate token is not empty
    if [[ -z "$token" ]]; then
        print_error "Token cannot be empty"
        return 1
    fi
    
    # Save token to file
    if echo "$token" > "$token_file"; then
        print_success "Token saved to $token_file"
        return 0
    else
        print_error "Failed to save token to $token_file"
        return 1
    fi
}

# Step 7: Configure Mods
# Parses modoverrides.lua from both shards and generates dedicated_server_mods_setup.lua
# Also creates Steam Workshop directory structure to prevent download errors
# Returns: 0 on success (even if no mods found), 1 on failure
step_configure_mods() {
    print_step 7 "Configuring Mods"
    
    # Display mod directory explanation
    echo
    print_info "Mod Directory Structure:"
    echo -e "  ${BOLD}Server Mods:${NC} $SERVER_MODS_DIR"
    echo "    → Contains dedicated_server_mods_setup.lua (download list)"
    echo -e "  ${BOLD}Cluster Mods:${NC} $DEDI_SERVER_DIR/mods/"
    echo "    → Contains modoverrides.lua (mod settings)"
    echo
    print_info "The server will download mods from Steam Workshop on startup"
    echo
    
    # Create Steam Workshop directory structure to prevent download errors
    # Without these directories, the server fails with:
    # "Staging library folder not found" / "Install library folder not found"
    print_info "Setting up Steam Workshop directory structure..."
    
    local steam_content_dir="$SERVER_DIR/steamapps"
    local workshop_dir="$steam_content_dir/workshop"
    local dst_workshop_id="322330"  # Workshop uses the game's app ID
    
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
            mkdir -p "$dir" 2>/dev/null || true
        fi
    done
    
    # Create workshop manifest file if it doesn't exist
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
    fi
    
    # Create library folders manifest if it doesn't exist
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
			"$DST_APP_ID"		"0"
		}
	}
}
EOF
    fi
    
    print_success "Steam Workshop directories ready"
    
    local mod_ids=()
    
    # Parse modoverrides.lua from both Master and Caves shards
    print_info "Scanning for mods in cluster configuration..."
    
    for shard in Master Caves; do
        local override_file="$DEDI_SERVER_DIR/$shard/modoverrides.lua"
        
        if [[ -f "$override_file" ]]; then
            print_info "Parsing $shard/modoverrides.lua..."
            
            # Extract workshop IDs using grep
            # Pattern: workshop-[0-9]+ (e.g., workshop-1185229307)
            # -o: only matching part
            # -P: Perl regex
            # \K: keep everything before this, discard in output
            while IFS= read -r id; do
                [[ -n "$id" ]] && mod_ids+=("$id")
            done < <(grep -oP 'workshop-\K[0-9]+' "$override_file" 2>/dev/null || true)
        else
            print_warning "$shard/modoverrides.lua not found"
        fi
    done
    
    # Remove duplicates by sorting and getting unique values
    if [[ ${#mod_ids[@]} -gt 0 ]]; then
        readarray -t mod_ids < <(printf '%s\n' "${mod_ids[@]}" | sort -u)
    fi
    
    # Check if any mods were found
    if [[ ${#mod_ids[@]} -eq 0 ]]; then
        print_warning "No mods found in cluster configuration"
        print_info "Your server will run without mods"
        return 0
    fi
    
    print_success "Found ${#mod_ids[@]} unique mod(s)"
    
    # Create Server Mods directory if it doesn't exist
    if ! mkdir -p "$SERVER_MODS_DIR"; then
        print_error "Failed to create Server Mods directory: $SERVER_MODS_DIR"
        return 1
    fi
    
    # Generate dedicated_server_mods_setup.lua
    local setup_file="$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    
    print_info "Generating $setup_file..."
    
    # Write the mod setup file
    {
        echo "-- Auto-generated by DST Server Setup Wizard"
        echo "-- $(date)"
        echo "-- Mods will be downloaded from Steam Workshop on server start"
        echo ""
        for id in "${mod_ids[@]}"; do
            echo "ServerModSetup(\"$id\")"
        done
    } > "$setup_file"
    
    if [[ ! -f "$setup_file" ]]; then
        print_error "Failed to create mod setup file"
        return 1
    fi
    
    print_success "Created $setup_file"
    echo
    print_info "Configured mods:"
    for id in "${mod_ids[@]}"; do
        echo "  - Workshop ID: $id"
    done
    echo
    print_success "Mods will be downloaded automatically when server starts"
    
    return 0
}

# Step 8: Start Server
# Displays startup commands and launches Master and Caves shards as background processes
# Returns: 0 on success, 1 on failure
step_start_server() {
    print_step 8 "Starting DST Server"
    
    local server_exe="$SERVER_DIR/bin64/dontstarve_dedicated_server_nullrenderer_x64"
    
    # Verify server executable exists
    if [[ ! -f "$server_exe" ]]; then
        print_error "Server executable not found: $server_exe"
        print_info "Please run Step 3 to install the DST server"
        return 1
    fi
    
    # Display startup commands
    echo
    print_info "Server startup commands:"
    echo
    echo -e "  ${CYAN}cd $SERVER_DIR/bin64${NC}"
    echo -e "  ${CYAN}./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master${NC}"
    echo -e "  ${CYAN}./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves${NC}"
    echo
    
    # Prompt for startup method
    echo
    print_info "How would you like to start the server?"
    echo "  1) Background processes (original method)"
    echo "  2) Separate terminal windows (recommended for monitoring)"
    echo "  3) Don't start now (manual start later)"
    echo
    
    local choice
    read -rp "Enter choice [1-3]: " choice
    
    case "$choice" in
        1)
            # Background processes method
            cd "$SERVER_DIR/bin64" || {
                print_error "Failed to change to server directory: $SERVER_DIR/bin64"
                return 1
            }
            
            print_info "Starting Master shard in background..."
            ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Master &
            local master_pid=$!
            
            sleep 2
            
            print_info "Starting Caves shard in background..."
            ./dontstarve_dedicated_server_nullrenderer_x64 -cluster MyDediServer -shard Caves &
            local caves_pid=$!
            
            cd - >/dev/null || true
            
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
            ;;
            
        2)
            # Separate terminal windows method
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
                print_info "Please install: kitty, gnome-terminal, konsole, xfce4-terminal, or xterm"
                return 1
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
            print_info "Close the terminal windows to stop the servers."
            ;;
            
        3)
            print_info "You can start the server manually using the commands above"
            print_success "Setup complete! Server is ready to start."
            return 0
            ;;
            
        *)
            print_error "Invalid choice. Please run the wizard again."
            return 1
            ;;
    esac
    
    echo
    print_info "To stop the server:"
    echo "  kill $master_pid $caves_pid"
    echo
    print_info "To view logs in real-time:"
    echo "  tail -f $DEDI_SERVER_DIR/Master/server_log.txt"
    echo "  tail -f $DEDI_SERVER_DIR/Caves/server_log.txt"
    
    return 0
}

# ============================================================================
# Exit Codes
# ============================================================================

readonly EXIT_SUCCESS=0
readonly EXIT_DEPENDENCY_MISSING=1
readonly EXIT_STEAMCMD_INSTALL_FAILED=2
readonly EXIT_DST_INSTALL_FAILED=3
readonly EXIT_DIRECTORY_FAILED=4
readonly EXIT_NO_CLUSTERS=5
readonly EXIT_MIGRATION_FAILED=6
readonly EXIT_AUTH_FAILED=7
readonly EXIT_MOD_CONFIG_FAILED=8
readonly EXIT_SERVER_START_FAILED=9
readonly EXIT_USER_CANCELLED=10
readonly EXIT_INTERRUPTED=130

# ============================================================================
# Cleanup and Error Handling
# ============================================================================

# Track temporary files and directories for cleanup
TEMP_FILES=()
TEMP_DIRS=()

# Register a temporary file for cleanup
# Usage: register_temp_file "/path/to/file"
register_temp_file() {
    TEMP_FILES+=("$1")
}

# Register a temporary directory for cleanup
# Usage: register_temp_dir "/path/to/dir"
register_temp_dir() {
    TEMP_DIRS+=("$1")
}

# Cleanup function - removes all registered temporary files and directories
# Called automatically on script exit via trap
cleanup() {
    local exit_code=$?
    
    # Only show cleanup message if there's something to clean
    if [[ ${#TEMP_FILES[@]} -gt 0 ]] || [[ ${#TEMP_DIRS[@]} -gt 0 ]]; then
        echo
        print_info "Cleaning up temporary files..."
    fi
    
    # Remove temporary files
    for file in "${TEMP_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file" 2>/dev/null || true
        fi
    done
    
    # Remove temporary directories
    for dir in "${TEMP_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            rm -rf "$dir" 2>/dev/null || true
        fi
    done
    
    # Restore cursor visibility (in case it was hidden)
    tput cnorm 2>/dev/null || true
    
    return $exit_code
}

# Signal handler for interruption (Ctrl+C, SIGTERM)
# Displays message and performs cleanup before exiting
handle_interrupt() {
    echo
    echo
    print_warning "Setup interrupted by user"
    print_info "Cleaning up..."
    cleanup
    exit $EXIT_INTERRUPTED
}

# Set up traps for cleanup and interruption
trap cleanup EXIT
trap handle_interrupt INT TERM

# ============================================================================
# Main Execution Flow
# ============================================================================

# Main function - orchestrates the entire setup wizard
# Executes all 8 steps sequentially and handles failures appropriately
# Returns: Appropriate exit code based on success or failure point
main() {
    # Clear screen for clean display
    clear
    
    # Display welcome banner
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║     Don't Starve Together - Dedicated Server Setup        ║${NC}"
    echo -e "${BOLD}║                    for Arch Linux                          ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo
    
    # Display step overview
    print_info "This wizard will guide you through ${TOTAL_STEPS} steps:"
    echo "  1. Check Dependencies"
    echo "  2. Install SteamCMD"
    echo "  3. Install DST Dedicated Server"
    echo "  4. Setup Server Directory Structure"
    echo "  5. Select & Migrate Cluster"
    echo "  6. Configure Server Authentication"
    echo "  7. Configure Mods"
    echo "  8. Start Server"
    echo
    
    # Prompt to begin setup
    if ! confirm "Ready to begin?"; then
        echo
        print_info "Setup cancelled by user."
        exit $EXIT_USER_CANCELLED
    fi
    
    # Execute steps sequentially
    # Each step must succeed before proceeding to the next
    # If any step fails, display error and exit with appropriate code
    
    step_check_dependencies || {
        print_error "Setup failed at Step 1: Dependency Check"
        exit $EXIT_DEPENDENCY_MISSING
    }
    
    step_install_steamcmd || {
        print_error "Setup failed at Step 2: SteamCMD Installation"
        exit $EXIT_STEAMCMD_INSTALL_FAILED
    }
    
    step_install_dst_server || {
        print_error "Setup failed at Step 3: DST Server Installation"
        exit $EXIT_DST_INSTALL_FAILED
    }
    
    step_setup_directories || {
        print_error "Setup failed at Step 4: Directory Setup"
        exit $EXIT_DIRECTORY_FAILED
    }
    
    step_migrate_cluster || {
        print_error "Setup failed at Step 5: Cluster Migration"
        exit $EXIT_NO_CLUSTERS
    }
    
    step_configure_auth || {
        print_error "Setup failed at Step 6: Authentication Setup"
        exit $EXIT_AUTH_FAILED
    }
    
    step_configure_mods || {
        print_error "Setup failed at Step 7: Mod Configuration"
        exit $EXIT_MOD_CONFIG_FAILED
    }
    
    step_start_server || {
        print_error "Setup failed at Step 8: Server Startup"
        exit $EXIT_SERVER_START_FAILED
    }
    
    # Display final success message
    echo
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  ✓ Setup Complete! Your DST server is ready.              ${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo
    print_info "Your server is now running!"
    print_info "Players can connect to your server from the server browser."
    echo
    print_info "Server Details:"
    echo "  Cluster: MyDediServer"
    echo "  Location: $DEDI_SERVER_DIR"
    echo
    print_success "Happy gaming!"
    
    exit $EXIT_SUCCESS
}

# ============================================================================
# Script Execution
# ============================================================================

# Execute main function with all command-line arguments
# Skip execution if being sourced (for testing)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
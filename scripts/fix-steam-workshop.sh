#!/bin/bash
# fix-steam-workshop.sh - Fix Steam Workshop mod download issues for DST Dedicated Server
# 
# This script creates the required Steam library folder structure that the DST server
# needs to download Workshop mods. Without these directories, you'll see errors like:
#   - "Staging library folder not found"
#   - "Install library folder not found"
#   - "ODPF failed entirely: 16"

set -e

# Configuration
readonly SERVER_DIR="$HOME/steamapps/DST"
readonly STEAM_CONTENT_DIR="$SERVER_DIR/steamapps"
readonly WORKSHOP_DIR="$STEAM_CONTENT_DIR/workshop"
readonly DST_APP_ID="343050"
readonly DST_WORKSHOP_ID="322330"  # Workshop uses the game's app ID, not server

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}!${NC} $1"; }
print_info() { echo -e "${BLUE}→${NC} $1"; }

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     DST Workshop Mod Download Fix                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo

print_info "This script fixes the 'Staging/Install library folder not found' error"
print_info "by creating the required Steam directory structure."
echo

# Check if server directory exists
if [[ ! -d "$SERVER_DIR" ]]; then
    print_error "DST server directory not found: $SERVER_DIR"
    print_info "Please run dst-server-setup.sh first to install the server."
    exit 1
fi

print_info "Creating Steam Workshop directory structure..."

# Create the steamapps directory structure
# The DST server expects these directories to exist for Workshop downloads
directories=(
    "$STEAM_CONTENT_DIR"
    "$WORKSHOP_DIR"
    "$WORKSHOP_DIR/content"
    "$WORKSHOP_DIR/content/$DST_WORKSHOP_ID"
    "$WORKSHOP_DIR/downloads"
    "$WORKSHOP_DIR/temp"
    "$STEAM_CONTENT_DIR/downloading"
    "$STEAM_CONTENT_DIR/temp"
)

for dir in "${directories[@]}"; do
    if [[ -d "$dir" ]]; then
        print_info "Directory exists: $dir"
    else
        if mkdir -p "$dir"; then
            print_success "Created: $dir"
        else
            print_error "Failed to create: $dir"
            exit 1
        fi
    fi
done

# Create the appworkshop ACF file that Steam uses to track workshop items
# This file tells the DST server where to find downloaded mods
acf_file="$WORKSHOP_DIR/appworkshop_$DST_WORKSHOP_ID.acf"

if [[ ! -f "$acf_file" ]]; then
    print_info "Creating workshop manifest file..."
    cat > "$acf_file" << EOF
"AppWorkshop"
{
	"appid"		"$DST_WORKSHOP_ID"
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
    print_success "Created: $acf_file"
else
    print_info "Workshop manifest exists: $acf_file"
fi

# Create libraryfolders.vdf if it doesn't exist
# This tells Steam where to find the library
library_file="$STEAM_CONTENT_DIR/libraryfolders.vdf"

if [[ ! -f "$library_file" ]]; then
    print_info "Creating library folders manifest..."
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
    print_success "Created: $library_file"
else
    print_info "Library manifest exists: $library_file"
fi

echo
print_success "Steam Workshop directory structure is ready!"
echo
print_info "Next steps:"
echo "  1. Start your DST server"
echo "  2. Mods should now download automatically"
echo
print_info "If mods still fail to download, try:"
echo "  1. Stop the server"
echo "  2. Run: steamcmd +force_install_dir $SERVER_DIR +login anonymous +app_update $DST_APP_ID +quit"
echo "  3. Start the server again"

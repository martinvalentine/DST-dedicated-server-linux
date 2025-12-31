#!/usr/bin/env bats
# Property Test: Mod ID Extraction and Setup Generation
#
# Validates that workshop IDs are extracted from modoverrides.lua and
# dedicated_server_mods_setup.lua is generated with unique mod IDs.

# Load the script functions
setup() {
    # Create a temporary directory for test isolation
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    
    # Create a test HOME directory
    export TEST_HOME="$TEST_DIR/home"
    mkdir -p "$TEST_HOME"
    
    # Save original HOME and use test HOME
    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_HOME"
    
    # Source the script with our test HOME
    source ./dst-server-setup.sh 2>/dev/null || true
    
    # Create base directory structure
    mkdir -p "$DEDI_SERVER_DIR/Master"
    mkdir -p "$DEDI_SERVER_DIR/Caves"
    mkdir -p "$SERVER_MODS_DIR"
}

teardown() {
    # Restore original HOME
    export HOME="$ORIGINAL_HOME"
    
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Helper function to create modoverrides.lua with given mod IDs
create_modoverrides() {
    local shard=$1
    shift
    local mod_ids=("$@")
    
    local override_file="$DEDI_SERVER_DIR/$shard/modoverrides.lua"
    
    {
        echo "return {"
        for id in "${mod_ids[@]}"; do
            echo "  [\"workshop-$id\"] = { enabled = true },"
        done
        echo "}"
    } > "$override_file"
}

# Property test: Extracts mod IDs from Master shard
@test "Property 4: Extracts workshop IDs from Master/modoverrides.lua" {
    # Create modoverrides.lua in Master with some mods
    create_modoverrides "Master" "1185229307" "1595631294" "2032685784"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Verify setup file was created
    [ -f "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua" ]
    
    # Verify all mod IDs are present
    grep -q 'ServerModSetup("1185229307")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    grep -q 'ServerModSetup("1595631294")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    grep -q 'ServerModSetup("2032685784")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
}

# Property test: Extracts mod IDs from Caves shard
@test "Property 4: Extracts workshop IDs from Caves/modoverrides.lua" {
    # Create modoverrides.lua in Caves with some mods
    create_modoverrides "Caves" "1185229307" "1595631294"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Verify setup file was created
    [ -f "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua" ]
    
    # Verify mod IDs are present
    grep -q 'ServerModSetup("1185229307")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    grep -q 'ServerModSetup("1595631294")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
}

# Property test: Extracts unique mod IDs from both shards
@test "Property 4: Extracts unique mod IDs from both Master and Caves" {
    # Create modoverrides.lua in both shards with overlapping mods
    create_modoverrides "Master" "1185229307" "1595631294" "2032685784"
    create_modoverrides "Caves" "1185229307" "1595631294" "3456789012"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Verify setup file was created
    [ -f "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua" ]
    
    # Count occurrences of each mod ID (should be exactly 1 each)
    [ "$(grep -c 'ServerModSetup("1185229307")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 1 ]
    [ "$(grep -c 'ServerModSetup("1595631294")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 1 ]
    [ "$(grep -c 'ServerModSetup("2032685784")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 1 ]
    [ "$(grep -c 'ServerModSetup("3456789012")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 1 ]
    
    # Verify total number of ServerModSetup calls is 4 (unique mods)
    [ "$(grep -c 'ServerModSetup' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 4 ]
}

# Property test: Removes duplicate mod IDs
@test "Property 4: Generates exactly one ServerModSetup call per unique mod ID" {
    # Create modoverrides with same mod in both shards
    create_modoverrides "Master" "1185229307" "1185229307" "1595631294"
    create_modoverrides "Caves" "1185229307" "1595631294"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Each unique mod should appear exactly once
    [ "$(grep -c 'ServerModSetup("1185229307")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 1 ]
    [ "$(grep -c 'ServerModSetup("1595631294")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 1 ]
    
    # Total should be 2 unique mods
    [ "$(grep -c 'ServerModSetup' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 2 ]
}

# Property test: Handles no mods gracefully
@test "Property 4: Handles empty modoverrides.lua gracefully" {
    # Create empty modoverrides files
    echo "return {}" > "$DEDI_SERVER_DIR/Master/modoverrides.lua"
    echo "return {}" > "$DEDI_SERVER_DIR/Caves/modoverrides.lua"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Should display warning about no mods
    [[ "$output" == *"No mods found"* ]]
}

# Property test: Handles missing modoverrides.lua files
@test "Property 4: Handles missing modoverrides.lua files" {
    # Don't create any modoverrides.lua files
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Should display warnings and continue
    [[ "$output" == *"not found"* ]]
    [[ "$output" == *"No mods found"* ]]
}

# Property test: Extracts only numeric workshop IDs
@test "Property 4: Extracts only numeric workshop IDs matching pattern" {
    # Create modoverrides with various patterns
    {
        echo "return {"
        echo "  [\"workshop-1185229307\"] = { enabled = true },"
        echo "  [\"workshop-abc\"] = { enabled = true },"  # Invalid - should be ignored
        echo "  [\"local-mod\"] = { enabled = true },"     # Invalid - should be ignored
        echo "  [\"workshop-2032685784\"] = { enabled = true },"
        echo "}"
    } > "$DEDI_SERVER_DIR/Master/modoverrides.lua"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Should only extract numeric IDs
    grep -q 'ServerModSetup("1185229307")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    grep -q 'ServerModSetup("2032685784")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    
    # Should not extract non-numeric patterns
    ! grep -q 'ServerModSetup("abc")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    ! grep -q 'local-mod' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    
    # Total should be 2 valid mods
    [ "$(grep -c 'ServerModSetup' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 2 ]
}

# Property test: Generates correct ServerModSetup format
@test "Property 4: Generates ServerModSetup calls with correct format" {
    # Create modoverrides with a mod
    create_modoverrides "Master" "1185229307"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Verify exact format: ServerModSetup("ID")
    grep -q '^ServerModSetup("1185229307")$' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
}

# Property test: Creates Server Mods directory if missing
@test "Property 4: Creates Server Mods directory if it doesn't exist" {
    # Remove the Server Mods directory
    rm -rf "$SERVER_MODS_DIR"
    
    # Create modoverrides with a mod
    create_modoverrides "Master" "1185229307"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Verify directory was created
    [ -d "$SERVER_MODS_DIR" ]
    
    # Verify setup file was created
    [ -f "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua" ]
}

# Property test: Handles large number of mods
@test "Property 4: Handles multiple mods correctly" {
    # Create modoverrides with many mods
    local mod_ids=("1185229307" "1595631294" "2032685784" "3456789012" "4567890123" "5678901234" "6789012345" "7890123456")
    create_modoverrides "Master" "${mod_ids[@]}"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Verify all mods are present
    for id in "${mod_ids[@]}"; do
        grep -q "ServerModSetup(\"$id\")" "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    done
    
    # Verify count
    [ "$(grep -c 'ServerModSetup' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq ${#mod_ids[@]} ]
}

# Property test: Displays mod count in output
@test "Property 4: Displays correct count of unique mods found" {
    # Create modoverrides with 3 unique mods
    create_modoverrides "Master" "1185229307" "1595631294"
    create_modoverrides "Caves" "1595631294" "2032685784"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Should display "Found 3 unique mod(s)"
    [[ "$output" == *"Found 3 unique mod(s)"* ]]
}

# Property test: Displays mod IDs in output
@test "Property 4: Lists all configured mod IDs in output" {
    # Create modoverrides with some mods
    create_modoverrides "Master" "1185229307" "1595631294"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Should list the mod IDs
    [[ "$output" == *"Workshop ID: 1185229307"* ]]
    [[ "$output" == *"Workshop ID: 1595631294"* ]]
}

# Property test: File contains header comment
@test "Property 4: Generated file contains auto-generated header" {
    # Create modoverrides with a mod
    create_modoverrides "Master" "1185229307"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Verify header comment exists
    grep -q "Auto-generated by DST Server Setup Wizard" "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
}

# Property test: Handles mods with configuration options
@test "Property 4: Extracts mod IDs regardless of configuration options" {
    # Create modoverrides with complex configuration
    {
        echo "return {"
        echo "  [\"workshop-1185229307\"] = {"
        echo "    enabled = true,"
        echo "    configuration_options = {"
        echo "      option1 = \"value1\","
        echo "      option2 = 42"
        echo "    }"
        echo "  },"
        echo "  [\"workshop-1595631294\"] = { enabled = false },"
        echo "}"
    } > "$DEDI_SERVER_DIR/Master/modoverrides.lua"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Should extract both mod IDs regardless of enabled status or options
    grep -q 'ServerModSetup("1185229307")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    grep -q 'ServerModSetup("1595631294")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
}

# Property test: Handles workshop IDs with different digit lengths
@test "Property 4: Correctly extracts workshop IDs of varying lengths" {
    # Create modoverrides with IDs of different lengths
    create_modoverrides "Master" "123" "1234567890" "999999999999"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Verify all IDs extracted correctly
    grep -q 'ServerModSetup("123")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    grep -q 'ServerModSetup("1234567890")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
    grep -q 'ServerModSetup("999999999999")' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua"
}

# Property test: Success message displayed
@test "Property 4: Displays success message after configuration" {
    # Create modoverrides with a mod
    create_modoverrides "Master" "1185229307"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Should display success messages
    [[ "$output" == *"Created"* ]]
    [[ "$output" == *"dedicated_server_mods_setup.lua"* ]]
    [[ "$output" == *"Mods will be downloaded automatically"* ]]
}

# Property test: Handles only Master shard having mods
@test "Property 4: Works when only Master shard has mods" {
    # Only create modoverrides in Master
    create_modoverrides "Master" "1185229307" "1595631294"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Should still work and extract mods
    [ -f "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua" ]
    [ "$(grep -c 'ServerModSetup' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 2 ]
}

# Property test: Handles only Caves shard having mods
@test "Property 4: Works when only Caves shard has mods" {
    # Only create modoverrides in Caves
    create_modoverrides "Caves" "1185229307" "1595631294"
    
    run step_configure_mods
    
    [ "$status" -eq 0 ]
    
    # Should still work and extract mods
    [ -f "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua" ]
    [ "$(grep -c 'ServerModSetup' "$SERVER_MODS_DIR/dedicated_server_mods_setup.lua")" -eq 2 ]
}

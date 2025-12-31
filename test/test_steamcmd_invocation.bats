#!/usr/bin/env bats
# Property Test: SteamCMD Invocation Correctness
#
# Validates that SteamCMD is invoked with correct parameters for DST server.

# Load the script functions
setup() {
    # Create a temporary directory for test isolation
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    
    # We need to load the script in a way that allows us to test it
    # Since SERVER_DIR is readonly, we'll work with the actual HOME-based paths
    # but use a test-specific HOME directory
    export TEST_HOME="$TEST_DIR/home"
    mkdir -p "$TEST_HOME"
    
    # Temporarily change HOME for this test
    export ORIGINAL_HOME="$HOME"
    export HOME="$TEST_HOME"
    
    # Now source the script - it will use our TEST_HOME
    source ./dst-server-setup.sh 2>/dev/null || true
    
    # Create directory structure
    mkdir -p "$HOME/steamapps/DST/bin64"
}

teardown() {
    # Restore original HOME
    export HOME="$ORIGINAL_HOME"
    
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Helper function to create a mock steamcmd that logs its invocation
create_mock_steamcmd() {
    local should_succeed=${1:-true}
    
    cat > "$TEST_DIR/steamcmd" << 'MOCK_SCRIPT'
#!/bin/bash
# Mock steamcmd for testing - logs all arguments

SHOULD_SUCCEED=PLACEHOLDER_SUCCESS
LOG_FILE="PLACEHOLDER_LOG"

# Log all arguments
echo "steamcmd invoked with arguments:" >> "$LOG_FILE"
for arg in "$@"; do
    echo "  $arg" >> "$LOG_FILE"
done

# Create the server executable if successful
if [[ "$SHOULD_SUCCEED" == "true" ]]; then
    # Find the force_install_dir argument
    install_dir=""
    next_is_dir=false
    for arg in "$@"; do
        if [[ "$next_is_dir" == "true" ]]; then
            install_dir="$arg"
            break
        fi
        if [[ "$arg" == "+force_install_dir" ]]; then
            next_is_dir=true
        fi
    done
    
    if [[ -n "$install_dir" ]]; then
        mkdir -p "$install_dir/bin64"
        touch "$install_dir/bin64/dontstarve_dedicated_server_nullrenderer_x64"
    fi
    exit 0
else
    exit 1
fi
MOCK_SCRIPT
    
    # Replace placeholders
    sed -i "s|PLACEHOLDER_SUCCESS|$should_succeed|" "$TEST_DIR/steamcmd"
    sed -i "s|PLACEHOLDER_LOG|$TEST_DIR/steamcmd.log|" "$TEST_DIR/steamcmd"
    chmod +x "$TEST_DIR/steamcmd"
}

# Property test: SteamCMD is invoked with force_install_dir parameter
@test "Property 6: SteamCMD invoked with force_install_dir parameter" {
    create_mock_steamcmd true
    export PATH="$TEST_DIR:$PATH"
    
    run step_install_dst_server
    
    # Should succeed
    [ "$status" -eq 0 ]
    
    # Check that steamcmd was called with force_install_dir
    grep -q "+force_install_dir" "$TEST_DIR/steamcmd.log"
    
    # Check that the directory points to $HOME/steamapps/DST
    grep -q "$HOME/steamapps/DST" "$TEST_DIR/steamcmd.log"
}

# Property test: SteamCMD is invoked with login anonymous
@test "Property 6: SteamCMD invoked with login anonymous" {
    create_mock_steamcmd true
    export PATH="$TEST_DIR:$PATH"
    
    run step_install_dst_server
    
    [ "$status" -eq 0 ]
    
    # Check that steamcmd was called with login anonymous
    grep -q "+login" "$TEST_DIR/steamcmd.log"
    grep -q "anonymous" "$TEST_DIR/steamcmd.log"
}

# Property test: SteamCMD is invoked with app_update 343050
@test "Property 6: SteamCMD invoked with app_update 343050" {
    create_mock_steamcmd true
    export PATH="$TEST_DIR:$PATH"
    
    run step_install_dst_server
    
    [ "$status" -eq 0 ]
    
    # Check that steamcmd was called with app_update 343050
    grep -q "+app_update" "$TEST_DIR/steamcmd.log"
    grep -q "343050" "$TEST_DIR/steamcmd.log"
}

# Property test: All three required parameters are present
@test "Property 6: SteamCMD invoked with all required parameters" {
    create_mock_steamcmd true
    export PATH="$TEST_DIR:$PATH"
    
    run step_install_dst_server
    
    [ "$status" -eq 0 ]
    
    # Verify all three required parameters are present
    grep -q "+force_install_dir" "$TEST_DIR/steamcmd.log"
    grep -q "$TEST_HOME/steamapps/DST" "$TEST_DIR/steamcmd.log"
    grep -q "+login" "$TEST_DIR/steamcmd.log"
    grep -q "anonymous" "$TEST_DIR/steamcmd.log"
    grep -q "+app_update" "$TEST_DIR/steamcmd.log"
    grep -q "343050" "$TEST_DIR/steamcmd.log"
}

# Property test: Correct parameter order and format
@test "Property 6: Parameters are in correct format with + prefix" {
    create_mock_steamcmd true
    export PATH="$TEST_DIR:$PATH"
    
    run step_install_dst_server
    
    [ "$status" -eq 0 ]
    
    # Check that parameters have the + prefix
    local log_content=$(cat "$TEST_DIR/steamcmd.log")
    [[ "$log_content" == *"+force_install_dir"* ]]
    [[ "$log_content" == *"+login"* ]]
    [[ "$log_content" == *"+app_update"* ]]
    [[ "$log_content" == *"+quit"* ]]
}

# Property test: Installation directory is correctly set
@test "Property 6: force_install_dir points to correct SERVER_DIR path" {
    create_mock_steamcmd true
    export PATH="$TEST_DIR:$PATH"
    
    run step_install_dst_server
    
    [ "$status" -eq 0 ]
    
    # The log should contain the HOME/steamapps/DST path
    grep -q "$HOME/steamapps/DST" "$TEST_DIR/steamcmd.log"
}

# Property test: Handles existing installation with update prompt
@test "Property 6: SteamCMD parameters remain correct when updating existing installation" {
    # Create existing server executable
    mkdir -p "$HOME/steamapps/DST/bin64"
    touch "$HOME/steamapps/DST/bin64/dontstarve_dedicated_server_nullrenderer_x64"
    
    create_mock_steamcmd true
    export PATH="$TEST_DIR:$PATH"
    
    # Simulate user choosing to update (answer 'y' to confirm prompt)
    # We need to pipe 'y' into the function
    run sh -c "echo 'y' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_install_dst_server'"
    
    # Should still invoke steamcmd with correct parameters
    grep -q "+force_install_dir" "$TEST_DIR/steamcmd.log"
    grep -q "+login" "$TEST_DIR/steamcmd.log"
    grep -q "anonymous" "$TEST_DIR/steamcmd.log"
    grep -q "+app_update" "$TEST_DIR/steamcmd.log"
    grep -q "343050" "$TEST_DIR/steamcmd.log"
}

# Property test: Verification after installation
@test "Property 6: Function verifies server executable exists after SteamCMD completes" {
    create_mock_steamcmd true
    export PATH="$TEST_DIR:$PATH"
    
    run step_install_dst_server
    
    # Should succeed
    [ "$status" -eq 0 ]
    
    # Server executable should exist
    [ -f "$HOME/steamapps/DST/bin64/dontstarve_dedicated_server_nullrenderer_x64" ]
    
    # Success message should be displayed
    [[ "$output" == *"DST server installed"* ]]
}

# Property test: Failure handling when executable not created
@test "Property 6: Returns failure when server executable not found after installation" {
    # Create a mock that succeeds but doesn't create the executable
    cat > "$TEST_DIR/steamcmd" << 'MOCK_SCRIPT'
#!/bin/bash
# Mock that succeeds but doesn't create executable
exit 0
MOCK_SCRIPT
    chmod +x "$TEST_DIR/steamcmd"
    
    export PATH="$TEST_DIR:$PATH"
    
    run step_install_dst_server
    
    # Should fail
    [ "$status" -eq 1 ]
    
    # Error message should indicate executable not found
    [[ "$output" == *"executable not found"* ]]
}

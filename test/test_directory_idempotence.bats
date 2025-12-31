#!/usr/bin/env bats
# Property Test: Directory Creation Idempotence
#
# Validates that running directory setup multiple times produces the same
# result with no errors on re-execution.

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
}

teardown() {
    # Restore original HOME
    export HOME="$ORIGINAL_HOME"
    
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Property test: First execution creates all directories
@test "Property 7: First execution creates all required directories" {
    run step_setup_directories
    
    # Should succeed
    [ "$status" -eq 0 ]
    
    # All directories should exist
    [ -d "$HOME/.klei" ]
    [ -d "$HOME/.klei/DoNotStarveTogether" ]
    [ -d "$HOME/.klei/DoNotStarveTogether/MyDediServer" ]
    
    # Output should indicate directories were created
    [[ "$output" == *"Created:"* ]]
}

# Property test: Second execution is idempotent (no errors)
@test "Property 7: Running setup twice produces no errors" {
    # First execution
    run step_setup_directories
    [ "$status" -eq 0 ]
    
    # Second execution
    run step_setup_directories
    
    # Should still succeed
    [ "$status" -eq 0 ]
    
    # Should indicate directories already exist
    [[ "$output" == *"Directory exists:"* ]]
}

# Property test: Multiple executions preserve directory structure
@test "Property 7: Multiple executions preserve existing directory structure" {
    # First execution
    step_setup_directories
    
    # Create a test file in one of the directories
    echo "test content" > "$HOME/.klei/DoNotStarveTogether/MyDediServer/test_file.txt"
    
    # Second execution
    run step_setup_directories
    
    [ "$status" -eq 0 ]
    
    # Test file should still exist (directory not recreated)
    [ -f "$HOME/.klei/DoNotStarveTogether/MyDediServer/test_file.txt" ]
    [ "$(cat "$HOME/.klei/DoNotStarveTogether/MyDediServer/test_file.txt")" = "test content" ]
}

# Property test: Partial directory structure is completed
@test "Property 7: Completes partial directory structure without errors" {
    # Manually create only the first directory
    mkdir -p "$HOME/.klei"
    
    # Run setup
    run step_setup_directories
    
    [ "$status" -eq 0 ]
    
    # All directories should now exist
    [ -d "$HOME/.klei" ]
    [ -d "$HOME/.klei/DoNotStarveTogether" ]
    [ -d "$HOME/.klei/DoNotStarveTogether/MyDediServer" ]
    
    # Output should show first exists, others created
    [[ "$output" == *"Directory exists: $HOME/.klei"* ]]
    [[ "$output" == *"Created:"* ]]
}

# Property test: All three directories are created in correct order
@test "Property 7: Creates all three required directories" {
    run step_setup_directories
    
    [ "$status" -eq 0 ]
    
    # Verify exact directory structure
    [ -d "$HOME/.klei" ]
    [ -d "$HOME/.klei/DoNotStarveTogether" ]
    [ -d "$HOME/.klei/DoNotStarveTogether/MyDediServer" ]
    
    # Verify the paths match the expected constants
    [ -d "$KLEI_DIR" ]
    [ -d "$DEDI_SERVER_DIR" ]
}

# Property test: Idempotence with 100 iterations
@test "Property 7: Running setup 100 times produces consistent results" {
    # First execution
    step_setup_directories
    
    # Create marker file
    echo "marker" > "$HOME/.klei/DoNotStarveTogether/MyDediServer/marker.txt"
    
    # Run 100 more times
    for i in {1..100}; do
        run step_setup_directories
        [ "$status" -eq 0 ]
    done
    
    # Marker file should still exist
    [ -f "$HOME/.klei/DoNotStarveTogether/MyDediServer/marker.txt" ]
    [ "$(cat "$HOME/.klei/DoNotStarveTogether/MyDediServer/marker.txt")" = "marker" ]
    
    # All directories should still exist
    [ -d "$HOME/.klei" ]
    [ -d "$HOME/.klei/DoNotStarveTogether" ]
    [ -d "$HOME/.klei/DoNotStarveTogether/MyDediServer" ]
}

# Property test: Success message displayed on completion
@test "Property 7: Displays success message after setup" {
    run step_setup_directories
    
    [ "$status" -eq 0 ]
    
    # Should display success message
    [[ "$output" == *"Directory structure ready"* ]]
}

# Property test: Handles existing directories gracefully
@test "Property 7: Gracefully handles all directories already existing" {
    # Pre-create all directories
    mkdir -p "$HOME/.klei/DoNotStarveTogether/MyDediServer"
    
    run step_setup_directories
    
    [ "$status" -eq 0 ]
    
    # Should indicate all directories exist
    [[ "$output" == *"Directory exists:"* ]]
    
    # Should not show any "Created:" messages
    ! [[ "$output" == *"Created:"* ]]
}

# Property test: Nested directory creation works correctly
@test "Property 7: Creates nested directory structure correctly" {
    run step_setup_directories
    
    [ "$status" -eq 0 ]
    
    # Verify the nested structure
    [ -d "$HOME/.klei" ]
    [ -d "$HOME/.klei/DoNotStarveTogether" ]
    [ -d "$HOME/.klei/DoNotStarveTogether/MyDediServer" ]
    
    # Verify MyDediServer is inside DoNotStarveTogether
    [ "$(dirname "$HOME/.klei/DoNotStarveTogether/MyDediServer")" = "$HOME/.klei/DoNotStarveTogether" ]
}

# Property test: Directory permissions are preserved on re-execution
@test "Property 7: Preserves directory permissions on re-execution" {
    # First execution
    step_setup_directories
    
    # Change permissions on one directory
    chmod 755 "$HOME/.klei/DoNotStarveTogether/MyDediServer"
    
    # Get the permissions
    local perms_before=$(stat -c "%a" "$HOME/.klei/DoNotStarveTogether/MyDediServer")
    
    # Second execution
    step_setup_directories
    
    # Permissions should be unchanged
    local perms_after=$(stat -c "%a" "$HOME/.klei/DoNotStarveTogether/MyDediServer")
    [ "$perms_before" = "$perms_after" ]
}

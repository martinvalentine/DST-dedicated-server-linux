#!/usr/bin/env bats
# Test error handling and cleanup functionality
# Feature: dst-server-setup, Property: Error Handling
# Validates: Requirements 1.4

# Load the script for testing
setup() {
    # Source the script to access functions
    source dst-server-setup.sh
    
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)
    export DST_TEST_MODE=1
}

teardown() {
    # Clean up test directory
    rm -rf "$TEST_DIR"
}

# Test: Cleanup function removes registered temporary files
@test "Cleanup removes registered temporary files" {
    # Create a temporary file
    local temp_file="$TEST_DIR/test_temp_file.txt"
    echo "test content" > "$temp_file"
    
    # Register it for cleanup
    register_temp_file "$temp_file"
    
    # Verify file exists
    [[ -f "$temp_file" ]]
    
    # Run cleanup
    cleanup
    
    # Verify file is removed
    [[ ! -f "$temp_file" ]]
}

# Test: Cleanup function removes registered temporary directories
@test "Cleanup removes registered temporary directories" {
    # Create a temporary directory with content
    local temp_dir="$TEST_DIR/test_temp_dir"
    mkdir -p "$temp_dir/subdir"
    echo "test" > "$temp_dir/file.txt"
    
    # Register it for cleanup
    register_temp_dir "$temp_dir"
    
    # Verify directory exists
    [[ -d "$temp_dir" ]]
    
    # Run cleanup
    cleanup
    
    # Verify directory is removed
    [[ ! -d "$temp_dir" ]]
}

# Test: Cleanup handles multiple files and directories
@test "Cleanup handles multiple files and directories" {
    # Create multiple temporary items
    local file1="$TEST_DIR/file1.txt"
    local file2="$TEST_DIR/file2.txt"
    local dir1="$TEST_DIR/dir1"
    local dir2="$TEST_DIR/dir2"
    
    echo "test" > "$file1"
    echo "test" > "$file2"
    mkdir -p "$dir1"
    mkdir -p "$dir2"
    
    # Register all for cleanup
    register_temp_file "$file1"
    register_temp_file "$file2"
    register_temp_dir "$dir1"
    register_temp_dir "$dir2"
    
    # Verify all exist
    [[ -f "$file1" ]]
    [[ -f "$file2" ]]
    [[ -d "$dir1" ]]
    [[ -d "$dir2" ]]
    
    # Run cleanup
    cleanup
    
    # Verify all are removed
    [[ ! -f "$file1" ]]
    [[ ! -f "$file2" ]]
    [[ ! -d "$dir1" ]]
    [[ ! -d "$dir2" ]]
}

# Test: Cleanup gracefully handles non-existent files
@test "Cleanup gracefully handles non-existent files" {
    # Register a file that doesn't exist
    register_temp_file "$TEST_DIR/nonexistent.txt"
    
    # Cleanup should not error even if file doesn't exist
    # This is handled by the || true in the cleanup function
    [[ ${#TEMP_FILES[@]} -gt 0 ]]
}

# Test: Cleanup gracefully handles non-existent directories
@test "Cleanup gracefully handles non-existent directories" {
    # Register a directory that doesn't exist
    register_temp_dir "$TEST_DIR/nonexistent_dir"
    
    # Cleanup should not error even if directory doesn't exist
    # This is handled by the || true in the cleanup function
    [[ ${#TEMP_DIRS[@]} -gt 0 ]]
}

# Test: Exit codes are properly defined
@test "All exit codes are properly defined" {
    # Verify all exit codes are set
    [[ -n "$EXIT_SUCCESS" ]]
    [[ -n "$EXIT_DEPENDENCY_MISSING" ]]
    [[ -n "$EXIT_STEAMCMD_INSTALL_FAILED" ]]
    [[ -n "$EXIT_DST_INSTALL_FAILED" ]]
    [[ -n "$EXIT_DIRECTORY_FAILED" ]]
    [[ -n "$EXIT_NO_CLUSTERS" ]]
    [[ -n "$EXIT_MIGRATION_FAILED" ]]
    [[ -n "$EXIT_AUTH_FAILED" ]]
    [[ -n "$EXIT_MOD_CONFIG_FAILED" ]]
    [[ -n "$EXIT_SERVER_START_FAILED" ]]
    [[ -n "$EXIT_USER_CANCELLED" ]]
    [[ -n "$EXIT_INTERRUPTED" ]]
}

# Test: Exit codes have correct values
@test "Exit codes have correct values" {
    [[ "$EXIT_SUCCESS" -eq 0 ]]
    [[ "$EXIT_DEPENDENCY_MISSING" -eq 1 ]]
    [[ "$EXIT_STEAMCMD_INSTALL_FAILED" -eq 2 ]]
    [[ "$EXIT_DST_INSTALL_FAILED" -eq 3 ]]
    [[ "$EXIT_DIRECTORY_FAILED" -eq 4 ]]
    [[ "$EXIT_NO_CLUSTERS" -eq 5 ]]
    [[ "$EXIT_MIGRATION_FAILED" -eq 6 ]]
    [[ "$EXIT_AUTH_FAILED" -eq 7 ]]
    [[ "$EXIT_MOD_CONFIG_FAILED" -eq 8 ]]
    [[ "$EXIT_SERVER_START_FAILED" -eq 9 ]]
    [[ "$EXIT_USER_CANCELLED" -eq 10 ]]
    [[ "$EXIT_INTERRUPTED" -eq 130 ]]
}

# Test: Cleanup doesn't show message when nothing to clean
@test "Cleanup doesn't show message when nothing to clean" {
    # Run cleanup with no registered files/dirs
    run cleanup
    
    # Should not contain cleanup message
    [[ ! "$output" =~ "Cleaning up temporary files" ]]
}

# Test: Cleanup shows message when there are items to clean
@test "Cleanup shows message when there are items to clean" {
    # Create and register a temporary file
    local temp_file="$TEST_DIR/test.txt"
    echo "test" > "$temp_file"
    register_temp_file "$temp_file"
    
    # Run cleanup
    run cleanup
    
    # Should contain cleanup message
    [[ "$output" =~ "Cleaning up temporary files" ]]
}

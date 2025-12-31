#!/usr/bin/env bats
# Property Test: Dependency Verification Completeness
#
# Validates that all missing dependencies are reported with install commands.

# Load the script functions
setup() {
    # Source the script to get access to functions
    # We need to prevent the script from running main
    source ./dst-server-setup.sh 2>/dev/null || true
    
    # Create a temporary directory for test isolation
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Helper function to create a mock pacman that simulates missing packages
create_mock_pacman() {
    local missing_packages=("$@")
    
    cat > "$TEST_DIR/pacman" << 'MOCK_SCRIPT'
#!/bin/bash
# Mock pacman for testing
MISSING_PACKAGES=(PLACEHOLDER_MISSING)

package_name=""
for arg in "$@"; do
    if [[ "$arg" != "-Qi" ]]; then
        package_name="$arg"
    fi
done

for missing in "${MISSING_PACKAGES[@]}"; do
    if [[ "$package_name" == "$missing" ]]; then
        exit 1
    fi
done
exit 0
MOCK_SCRIPT
    
    # Replace placeholder with actual missing packages
    local missing_str=""
    for pkg in "${missing_packages[@]}"; do
        missing_str+="\"$pkg\" "
    done
    sed -i "s/PLACEHOLDER_MISSING/$missing_str/" "$TEST_DIR/pacman"
    chmod +x "$TEST_DIR/pacman"
}

# Property test: All dependencies are checked (not just first failure)
# This tests that when multiple packages are missing, ALL are reported
@test "Property 2: reports ALL missing packages, not just the first one" {
    # Create mock pacman that reports git and lib32-glibc as missing
    create_mock_pacman "git" "lib32-glibc"
    
    # Override PATH to use mock pacman
    export PATH="$TEST_DIR:$PATH"
    
    # Run the dependency check and capture output
    run step_check_dependencies
    
    # Should fail (return 1) since packages are missing
    [ "$status" -eq 1 ]
    
    # Output should mention BOTH missing packages
    [[ "$output" == *"git"* ]]
    [[ "$output" == *"lib32-glibc"* ]]
    
    # Should show the installation command with both packages
    [[ "$output" == *"sudo pacman -S"* ]]
}

# Property test: Correct packages are checked
@test "Property 2: checks all four required dependencies" {
    # Create mock pacman where all packages are installed
    create_mock_pacman  # No missing packages
    
    export PATH="$TEST_DIR:$PATH"
    
    run step_check_dependencies
    
    # Should succeed
    [ "$status" -eq 0 ]
    
    # Output should mention all four packages being checked
    [[ "$output" == *"git"* ]]
    [[ "$output" == *"base-devel"* ]]
    [[ "$output" == *"lib32-gcc-libs"* ]]
    [[ "$output" == *"lib32-glibc"* ]]
}

# Property test: Installation command format is correct
@test "Property 2: provides correct installation command format" {
    # Create mock with single missing package
    create_mock_pacman "lib32-gcc-libs"
    
    export PATH="$TEST_DIR:$PATH"
    
    run step_check_dependencies
    
    [ "$status" -eq 1 ]
    
    # Should provide the correct pacman command
    [[ "$output" == *"sudo pacman -S lib32-gcc-libs"* ]]
}

# Property test: Success when all dependencies present
@test "Property 2: returns success when all dependencies are installed" {
    # All packages installed
    create_mock_pacman  # No missing packages
    
    export PATH="$TEST_DIR:$PATH"
    
    run step_check_dependencies
    
    # Should succeed
    [ "$status" -eq 0 ]
    [[ "$output" == *"All dependencies satisfied"* ]]
}

# Property test: Multiple missing packages in installation command
@test "Property 2: installation command includes all missing packages" {
    # Three packages missing
    create_mock_pacman "git" "base-devel" "lib32-glibc"
    
    export PATH="$TEST_DIR:$PATH"
    
    run step_check_dependencies
    
    [ "$status" -eq 1 ]
    
    # The installation command should include all three missing packages
    [[ "$output" == *"git"* ]]
    [[ "$output" == *"base-devel"* ]]
    [[ "$output" == *"lib32-glibc"* ]]
}

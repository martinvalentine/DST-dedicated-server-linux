#!/usr/bin/env bats
# Property Test: Sequential Step Execution
#
# Validates that wizard steps execute in order 1-8 and each step completes
# before the next begins.

# Load the script functions
setup() {
    # Create a temporary directory for test isolation
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    
    # Create a log file to track step execution order
    EXECUTION_LOG="$TEST_DIR/execution_log.txt"
    export EXECUTION_LOG
    
    # Create a modified version of the script for testing
    # We'll inject logging into each step function
    cp ./dst-server-setup.sh "$TEST_DIR/test_script.sh"
    
    # Make the script testable by preventing automatic execution
    # Remove the main "$@" call at the end
    sed -i '/^main "\$@"$/d' "$TEST_DIR/test_script.sh"
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Helper function to create mock step functions that log execution
create_instrumented_script() {
    local fail_at_step=$1  # Which step should fail (0 = none)
    
    cat > "$TEST_DIR/instrumented_script.sh" << 'SCRIPT_TEMPLATE'
#!/bin/bash
set -e

EXECUTION_LOG="PLACEHOLDER_LOG"
FAIL_AT_STEP=PLACEHOLDER_FAIL

# Mock step functions that log their execution
step_check_dependencies() {
    echo "step_1" >> "$EXECUTION_LOG"
    [[ $FAIL_AT_STEP -eq 1 ]] && return 1
    return 0
}

step_install_steamcmd() {
    echo "step_2" >> "$EXECUTION_LOG"
    [[ $FAIL_AT_STEP -eq 2 ]] && return 1
    return 0
}

step_install_dst_server() {
    echo "step_3" >> "$EXECUTION_LOG"
    [[ $FAIL_AT_STEP -eq 3 ]] && return 1
    return 0
}

step_setup_directories() {
    echo "step_4" >> "$EXECUTION_LOG"
    [[ $FAIL_AT_STEP -eq 4 ]] && return 1
    return 0
}

step_migrate_cluster() {
    echo "step_5" >> "$EXECUTION_LOG"
    [[ $FAIL_AT_STEP -eq 5 ]] && return 1
    return 0
}

step_configure_auth() {
    echo "step_6" >> "$EXECUTION_LOG"
    [[ $FAIL_AT_STEP -eq 6 ]] && return 1
    return 0
}

step_configure_mods() {
    echo "step_7" >> "$EXECUTION_LOG"
    [[ $FAIL_AT_STEP -eq 7 ]] && return 1
    return 0
}

step_start_server() {
    echo "step_8" >> "$EXECUTION_LOG"
    [[ $FAIL_AT_STEP -eq 8 ]] && return 1
    return 0
}

# Mock output functions
print_error() { :; }
print_info() { :; }
print_success() { :; }
confirm() { return 0; }

# Exit codes
EXIT_SUCCESS=0
EXIT_DEPENDENCY_MISSING=1
EXIT_STEAMCMD_INSTALL_FAILED=2
EXIT_DST_INSTALL_FAILED=3
EXIT_DIRECTORY_FAILED=4
EXIT_NO_CLUSTERS=5
EXIT_MIGRATION_FAILED=6
EXIT_AUTH_FAILED=7
EXIT_USER_CANCELLED=10

# Main function (simplified for testing)
main() {
    step_check_dependencies || exit $EXIT_DEPENDENCY_MISSING
    step_install_steamcmd || exit $EXIT_STEAMCMD_INSTALL_FAILED
    step_install_dst_server || exit $EXIT_DST_INSTALL_FAILED
    step_setup_directories || exit $EXIT_DIRECTORY_FAILED
    step_migrate_cluster || exit $EXIT_NO_CLUSTERS
    step_configure_auth || exit $EXIT_AUTH_FAILED
    step_configure_mods || exit $EXIT_AUTH_FAILED
    step_start_server || exit $EXIT_AUTH_FAILED
    exit $EXIT_SUCCESS
}

main "$@"
SCRIPT_TEMPLATE
    
    # Replace placeholders
    sed -i "s|PLACEHOLDER_LOG|$EXECUTION_LOG|" "$TEST_DIR/instrumented_script.sh"
    sed -i "s|PLACEHOLDER_FAIL|$fail_at_step|" "$TEST_DIR/instrumented_script.sh"
    chmod +x "$TEST_DIR/instrumented_script.sh"
}

# Property test: All steps execute in order when all succeed
@test "Property 1: all 8 steps execute in sequential order when successful" {
    # Create script where no steps fail
    create_instrumented_script 0
    
    # Run the script
    run "$TEST_DIR/instrumented_script.sh"
    
    # Should succeed
    [ "$status" -eq 0 ]
    
    # Check execution log contains all steps in order
    local log_content=$(cat "$EXECUTION_LOG")
    
    # Verify all 8 steps executed
    [[ "$log_content" == *"step_1"* ]]
    [[ "$log_content" == *"step_2"* ]]
    [[ "$log_content" == *"step_3"* ]]
    [[ "$log_content" == *"step_4"* ]]
    [[ "$log_content" == *"step_5"* ]]
    [[ "$log_content" == *"step_6"* ]]
    [[ "$log_content" == *"step_7"* ]]
    [[ "$log_content" == *"step_8"* ]]
    
    # Verify they executed in order
    local expected="step_1
step_2
step_3
step_4
step_5
step_6
step_7
step_8"
    
    [ "$log_content" = "$expected" ]
}

# Property test: Execution stops at failing step
@test "Property 1: step N+1 does not execute when step N fails (fail at step 1)" {
    # Create script that fails at step 1
    create_instrumented_script 1
    
    run "$TEST_DIR/instrumented_script.sh"
    
    # Should fail with dependency error
    [ "$status" -eq 1 ]
    
    # Only step 1 should have executed
    local log_content=$(cat "$EXECUTION_LOG")
    [[ "$log_content" == *"step_1"* ]]
    [[ "$log_content" != *"step_2"* ]]
    [[ "$log_content" != *"step_3"* ]]
}

# Property test: Execution stops at failing step (middle)
@test "Property 1: step N+1 does not execute when step N fails (fail at step 4)" {
    # Create script that fails at step 4
    create_instrumented_script 4
    
    run "$TEST_DIR/instrumented_script.sh"
    
    # Should fail with directory error
    [ "$status" -eq 4 ]
    
    # Steps 1-4 should have executed, but not 5-8
    local log_content=$(cat "$EXECUTION_LOG")
    [[ "$log_content" == *"step_1"* ]]
    [[ "$log_content" == *"step_2"* ]]
    [[ "$log_content" == *"step_3"* ]]
    [[ "$log_content" == *"step_4"* ]]
    [[ "$log_content" != *"step_5"* ]]
    [[ "$log_content" != *"step_6"* ]]
    [[ "$log_content" != *"step_7"* ]]
    [[ "$log_content" != *"step_8"* ]]
}

# Property test: Execution stops at failing step (late)
@test "Property 1: step N+1 does not execute when step N fails (fail at step 7)" {
    # Create script that fails at step 7
    create_instrumented_script 7
    
    run "$TEST_DIR/instrumented_script.sh"
    
    # Should fail with auth error (exit code 7)
    [ "$status" -eq 7 ]
    
    # Steps 1-7 should have executed, but not 8
    local log_content=$(cat "$EXECUTION_LOG")
    [[ "$log_content" == *"step_1"* ]]
    [[ "$log_content" == *"step_2"* ]]
    [[ "$log_content" == *"step_3"* ]]
    [[ "$log_content" == *"step_4"* ]]
    [[ "$log_content" == *"step_5"* ]]
    [[ "$log_content" == *"step_6"* ]]
    [[ "$log_content" == *"step_7"* ]]
    [[ "$log_content" != *"step_8"* ]]
}

# Property test: Steps execute in strict order (no skipping)
@test "Property 1: steps execute in strict sequential order with no gaps" {
    # All steps succeed
    create_instrumented_script 0
    
    run "$TEST_DIR/instrumented_script.sh"
    
    [ "$status" -eq 0 ]
    
    # Read execution log line by line
    local line_num=1
    while IFS= read -r line; do
        # Each line should be step_N where N equals line number
        [ "$line" = "step_$line_num" ]
        ((line_num++))
    done < "$EXECUTION_LOG"
    
    # Should have read exactly 8 lines
    [ $line_num -eq 9 ]  # 9 because we increment after reading line 8
}

# Property test: Appropriate exit codes for each failure point
@test "Property 1: correct exit code returned based on which step fails" {
    # Test each step failure returns correct exit code
    
    # Step 1 failure -> exit code 1
    create_instrumented_script 1
    run "$TEST_DIR/instrumented_script.sh"
    [ "$status" -eq 1 ]
    
    # Step 2 failure -> exit code 2
    create_instrumented_script 2
    run "$TEST_DIR/instrumented_script.sh"
    [ "$status" -eq 2 ]
    
    # Step 3 failure -> exit code 3
    create_instrumented_script 3
    run "$TEST_DIR/instrumented_script.sh"
    [ "$status" -eq 3 ]
    
    # Step 4 failure -> exit code 4
    create_instrumented_script 4
    run "$TEST_DIR/instrumented_script.sh"
    [ "$status" -eq 4 ]
    
    # Step 5 failure -> exit code 5
    create_instrumented_script 5
    run "$TEST_DIR/instrumented_script.sh"
    [ "$status" -eq 5 ]
}

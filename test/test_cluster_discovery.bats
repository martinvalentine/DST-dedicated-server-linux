#!/usr/bin/env bats
# Property Test: Cluster Discovery Pattern Matching
#
# Validates that cluster discovery only finds directories matching
# {numeric_id}/Cluster_[0-9]+ with cluster.ini, Master/, and Caves/.

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
    mkdir -p "$KLEI_DIR"
    mkdir -p "$DEDI_SERVER_DIR"
}

teardown() {
    # Restore original HOME
    export HOME="$ORIGINAL_HOME"
    
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
}

# Helper function to create a valid cluster
create_valid_cluster() {
    local user_id=$1
    local cluster_num=$2
    
    local cluster_path="$KLEI_DIR/$user_id/Cluster_$cluster_num"
    mkdir -p "$cluster_path/Master"
    mkdir -p "$cluster_path/Caves"
    touch "$cluster_path/cluster.ini"
}

# Helper function to create an invalid cluster (missing components)
create_invalid_cluster() {
    local user_id=$1
    local cluster_num=$2
    local missing=$3  # "ini", "master", or "caves"
    
    local cluster_path="$KLEI_DIR/$user_id/Cluster_$cluster_num"
    
    if [[ "$missing" != "master" ]]; then
        mkdir -p "$cluster_path/Master"
    fi
    
    if [[ "$missing" != "caves" ]]; then
        mkdir -p "$cluster_path/Caves"
    fi
    
    if [[ "$missing" != "ini" ]]; then
        touch "$cluster_path/cluster.ini"
    fi
}

# Property test: Discovers valid clusters with numeric user IDs
@test "Property 3: Discovers clusters in numeric user ID directories" {
    # Create valid clusters in numeric directories
    create_valid_cluster "999351396" "1"
    create_valid_cluster "123456789" "2"
    
    # Run with test mode enabled
    run bash -c 'export DST_TEST_MODE=1; source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'
    
    # Should succeed
    [ "$status" -eq 0 ]
    
    # Output should show found clusters
    [[ "$output" == *"Found 2 cluster(s)"* ]]
}

# Property test: Ignores non-numeric directories
@test "Property 3: Ignores non-numeric user ID directories" {
    # Create valid cluster in numeric directory
    create_valid_cluster "999351396" "1"
    
    # Create cluster in non-numeric directory (should be ignored)
    mkdir -p "$KLEI_DIR/not_a_number/Cluster_1/Master"
    mkdir -p "$KLEI_DIR/not_a_number/Cluster_1/Caves"
    touch "$KLEI_DIR/not_a_number/Cluster_1/cluster.ini"
    
    # Run with test mode enabled
    run bash -c 'export DST_TEST_MODE=1; source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'
    
    [ "$status" -eq 0 ]
    
    # Should only find 1 cluster (the one in numeric directory)
    [[ "$output" == *"Found 1 cluster(s)"* ]]
}

# Property test: Matches Cluster_[0-9]+ pattern correctly
@test "Property 3: Discovers only directories matching Cluster_[0-9]+ pattern" {
    # Create valid clusters with different numbers
    create_valid_cluster "999351396" "1"
    create_valid_cluster "999351396" "5"
    create_valid_cluster "999351396" "123"
    
    # Create invalid cluster names (should be ignored)
    mkdir -p "$KLEI_DIR/999351396/ClusterX/Master"
    mkdir -p "$KLEI_DIR/999351396/ClusterX/Caves"
    touch "$KLEI_DIR/999351396/ClusterX/cluster.ini"
    
    mkdir -p "$KLEI_DIR/999351396/Cluster_abc/Master"
    mkdir -p "$KLEI_DIR/999351396/Cluster_abc/Caves"
    touch "$KLEI_DIR/999351396/Cluster_abc/cluster.ini"
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Should only find 3 valid clusters
    [[ "$output" == *"Found 3 cluster(s)"* ]]
}

# Property test: Validates cluster contains cluster.ini
@test "Property 3: Rejects clusters missing cluster.ini" {
    # Create valid cluster
    create_valid_cluster "999351396" "1"
    
    # Create cluster without cluster.ini
    create_invalid_cluster "999351396" "2" "ini"
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Should only find 1 valid cluster
    [[ "$output" == *"Found 1 cluster(s)"* ]]
}

# Property test: Validates cluster contains Master/ directory
@test "Property 3: Rejects clusters missing Master/ directory" {
    # Create valid cluster
    create_valid_cluster "999351396" "1"
    
    # Create cluster without Master directory
    create_invalid_cluster "999351396" "2" "master"
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Should only find 1 valid cluster
    [[ "$output" == *"Found 1 cluster(s)"* ]]
}

# Property test: Validates cluster contains Caves/ directory
@test "Property 3: Rejects clusters missing Caves/ directory" {
    # Create valid cluster
    create_valid_cluster "999351396" "1"
    
    # Create cluster without Caves directory
    create_invalid_cluster "999351396" "2" "caves"
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Should only find 1 valid cluster
    [[ "$output" == *"Found 1 cluster(s)"* ]]
}

# Property test: All three validation criteria must be met
@test "Property 3: Requires cluster.ini, Master/, and Caves/ to be present" {
    # Create clusters missing different components
    create_invalid_cluster "999351396" "1" "ini"
    create_invalid_cluster "999351396" "2" "master"
    create_invalid_cluster "999351396" "3" "caves"
    
    # Create one valid cluster
    create_valid_cluster "999351396" "4"
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Should only find 1 valid cluster
    [[ "$output" == *"Found 1 cluster(s)"* ]]
}

# Property test: Returns error when no valid clusters found
@test "Property 3: Returns error when no valid clusters exist" {
    # Don't create any clusters
    
    run step_migrate_cluster
    
    # Should fail
    [ "$status" -eq 1 ]
    
    # Should display error message
    [[ "$output" == *"No valid clusters found"* ]]
    
    # Should provide instructions
    [[ "$output" == *"create a world in-game"* ]]
}

# Property test: Discovers clusters across multiple user IDs
@test "Property 3: Discovers clusters from multiple user ID directories" {
    # Create clusters in different user directories
    create_valid_cluster "111111111" "1"
    create_valid_cluster "222222222" "1"
    create_valid_cluster "333333333" "2"
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Should find all 3 clusters
    [[ "$output" == *"Found 3 cluster(s)"* ]]
}

# Property test: Cluster migration copies all files
@test "Property 3: Successfully migrates selected cluster to MyDediServer" {
    # Create valid cluster with some content
    create_valid_cluster "999351396" "1"
    echo "test_config" > "$KLEI_DIR/999351396/Cluster_1/cluster.ini"
    echo "master_config" > "$KLEI_DIR/999351396/Cluster_1/Master/server.ini"
    echo "caves_config" > "$KLEI_DIR/999351396/Cluster_1/Caves/server.ini"
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Verify files were copied
    [ -f "$DEDI_SERVER_DIR/cluster.ini" ]
    [ -f "$DEDI_SERVER_DIR/Master/server.ini" ]
    [ -f "$DEDI_SERVER_DIR/Caves/server.ini" ]
    
    # Verify content is correct
    [ "$(cat "$DEDI_SERVER_DIR/cluster.ini")" = "test_config" ]
    [ "$(cat "$DEDI_SERVER_DIR/Master/server.ini")" = "master_config" ]
    [ "$(cat "$DEDI_SERVER_DIR/Caves/server.ini")" = "caves_config" ]
}

# Property test: Pattern matching with various cluster numbers
@test "Property 3: Correctly matches clusters with single and multi-digit numbers" {
    # Create clusters with various number formats
    create_valid_cluster "999351396" "1"      # Single digit
    create_valid_cluster "999351396" "10"     # Two digits
    create_valid_cluster "999351396" "999"    # Three digits
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Should find all 3 clusters
    [[ "$output" == *"Found 3 cluster(s)"* ]]
}

# Property test: Handles empty KLEI_DIR gracefully
@test "Property 3: Handles empty DoNotStarveTogether directory" {
    # KLEI_DIR exists but is empty (no user directories)
    
    run step_migrate_cluster
    
    # Should fail gracefully
    [ "$status" -eq 1 ]
    [[ "$output" == *"No valid clusters found"* ]]
}

# Property test: Ignores files in user ID directory
@test "Property 3: Ignores files, only processes directories" {
    # Create valid cluster
    create_valid_cluster "999351396" "1"
    
    # Create a file that matches the pattern (should be ignored)
    touch "$KLEI_DIR/999351396/Cluster_2"
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Should only find 1 cluster (the directory, not the file)
    [[ "$output" == *"Found 1 cluster(s)"* ]]
}

# Property test: Displays user ID in cluster selection
@test "Property 3: Displays user ID alongside cluster name" {
    # Create cluster
    create_valid_cluster "999351396" "1"
    
    # Run and capture output
    run bash -c 'export DST_TEST_MODE=1; source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'
    
    [ "$status" -eq 0 ]
    
    # Output should show both cluster name and user ID
    [[ "$output" == *"Cluster_1"* ]]
    [[ "$output" == *"User: 999351396"* ]]
}

# Property test: Success message after migration
@test "Property 3: Displays success message after successful migration" {
    # Create valid cluster
    create_valid_cluster "999351396" "1"
    
    # Run with Enter to select first option
    run sh -c "echo -e '\n' | bash -c 'source ./dst-server-setup.sh 2>/dev/null; step_migrate_cluster'"
    
    [ "$status" -eq 0 ]
    
    # Should display success message
    [[ "$output" == *"Cluster migrated successfully"* ]]
}

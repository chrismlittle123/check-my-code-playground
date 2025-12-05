#!/bin/bash

# CMC Test Harness
# Runs all cmc commands across all projects and captures outputs

set -o pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/cmc-test-outputs"
PROJECTS_DIR="$SCRIPT_DIR/projects"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Commands to run in each project
# Format: "command_name|command_args|description"
COMMANDS=(
    "check||Run linter checks on entire project"
    "check|--json|Run linter checks with JSON output"
    "audit||Audit all linter configs"
    "audit|eslint|Audit ESLint config only"
    "audit|ruff|Audit Ruff config only"
    "generate|eslint --stdout|Generate ESLint config (stdout)"
    "generate|ruff --stdout|Generate Ruff config (stdout)"
    "context|--target claude --stdout|Generate Claude context (stdout)"
    "context|--target cursor --stdout|Generate Cursor context (stdout)"
    "context|--target copilot --stdout|Generate Copilot context (stdout)"
)

# Initialize output directory
init_output_dir() {
    rm -rf "$OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR"
    echo "Output directory: $OUTPUT_DIR"
}

# Get all project directories (those containing cmc.toml)
get_projects() {
    find "$PROJECTS_DIR" -name "cmc.toml" -exec dirname {} \; | sort
}

# Sanitize path for use as filename
sanitize_path() {
    echo "$1" | sed 's|/|__|g' | sed 's|^projects__||'
}

# Run a single command and capture output
run_command() {
    local project_dir="$1"
    local cmd_name="$2"
    local cmd_args="$3"
    local description="$4"
    local output_file="$5"

    local full_cmd="cmc $cmd_name $cmd_args"
    local start_time=$(date +%s.%N)

    # Create temp files for stdout and stderr
    local stdout_file=$(mktemp)
    local stderr_file=$(mktemp)

    # Run the command
    cd "$project_dir"
    eval "$full_cmd" > "$stdout_file" 2> "$stderr_file"
    local exit_code=$?

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")

    # Write to output file
    {
        echo "================================================================================"
        echo "CMC TEST OUTPUT"
        echo "================================================================================"
        echo ""
        echo "METADATA"
        echo "--------"
        echo "Timestamp:    $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Project:      $project_dir"
        echo "Command:      $full_cmd"
        echo "Description:  $description"
        echo "Exit Code:    $exit_code"
        echo "Duration:     ${duration}s"
        echo "CMC Version:  $(cmc --version 2>/dev/null || echo 'unknown')"
        echo ""
        echo "PROJECT FILES"
        echo "-------------"
        ls -la "$project_dir" 2>/dev/null || echo "(unable to list)"
        echo ""
        echo "CMC.TOML CONTENTS"
        echo "-----------------"
        cat "$project_dir/cmc.toml" 2>/dev/null || echo "(no cmc.toml found)"
        echo ""
        echo "STDOUT"
        echo "------"
        cat "$stdout_file"
        echo ""
        echo "STDERR"
        echo "------"
        cat "$stderr_file"
        echo ""
        echo "================================================================================"
    } > "$output_file"

    # Cleanup temp files
    rm -f "$stdout_file" "$stderr_file"

    # Return to original directory
    cd "$SCRIPT_DIR"

    # Return exit code for summary
    return $exit_code
}

# Create summary file
create_summary() {
    local summary_file="$OUTPUT_DIR/SUMMARY.txt"

    {
        echo "================================================================================"
        echo "CMC TEST HARNESS - SUMMARY REPORT"
        echo "================================================================================"
        echo ""
        echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "CMC Version: $(cmc --version 2>/dev/null || echo 'unknown')"
        echo ""
        echo "PROJECTS TESTED"
        echo "---------------"
        get_projects | while read -r project; do
            echo "  - $project"
        done
        echo ""
        echo "COMMANDS TESTED"
        echo "---------------"
        for cmd_spec in "${COMMANDS[@]}"; do
            IFS='|' read -r cmd_name cmd_args description <<< "$cmd_spec"
            echo "  - cmc $cmd_name $cmd_args"
            echo "    ($description)"
        done
        echo ""
        echo "RESULTS BY PROJECT"
        echo "------------------"
    } > "$summary_file"

    echo "$summary_file"
}

# Append result to summary
append_to_summary() {
    local summary_file="$1"
    local project="$2"
    local command="$3"
    local exit_code="$4"
    local output_file="$5"

    local status_icon="[PASS]"
    if [ "$exit_code" -ne 0 ]; then
        status_icon="[FAIL]"
    fi

    echo "  $status_icon $command -> $(basename "$output_file")" >> "$summary_file"
}

# Main execution
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}CMC Test Harness${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Initialize
    init_output_dir
    local summary_file=$(create_summary)

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Get all projects
    local projects=($(get_projects))
    local num_projects=${#projects[@]}

    echo -e "${YELLOW}Found $num_projects projects to test${NC}"
    echo -e "${YELLOW}Running ${#COMMANDS[@]} commands per project${NC}"
    echo ""

    # Iterate through each project
    for project in "${projects[@]}"; do
        local project_name=$(sanitize_path "${project#$PROJECTS_DIR/}")
        local project_output_dir="$OUTPUT_DIR/$project_name"
        mkdir -p "$project_output_dir"

        echo -e "${BLUE}Testing: $project${NC}"
        echo "" >> "$summary_file"
        echo "$project:" >> "$summary_file"

        # Run each command
        for cmd_spec in "${COMMANDS[@]}"; do
            IFS='|' read -r cmd_name cmd_args description <<< "$cmd_spec"

            # Create output filename
            local cmd_slug=$(echo "$cmd_name $cmd_args" | tr ' ' '_' | tr -cd '[:alnum:]_-')
            local output_file="$project_output_dir/${cmd_slug}.txt"

            # Run the command
            run_command "$project" "$cmd_name" "$cmd_args" "$description" "$output_file"
            local exit_code=$?

            ((total_tests++))
            if [ $exit_code -eq 0 ]; then
                ((passed_tests++))
                echo -e "  ${GREEN}[PASS]${NC} cmc $cmd_name $cmd_args"
            else
                ((failed_tests++))
                echo -e "  ${RED}[FAIL]${NC} cmc $cmd_name $cmd_args (exit: $exit_code)"
            fi

            append_to_summary "$summary_file" "$project" "cmc $cmd_name $cmd_args" "$exit_code" "$output_file"
        done
        echo ""
    done

    # Finalize summary
    {
        echo ""
        echo "================================================================================"
        echo "FINAL STATISTICS"
        echo "================================================================================"
        echo "Total Tests:  $total_tests"
        echo "Passed:       $passed_tests"
        echo "Failed:       $failed_tests"
        echo "Pass Rate:    $(echo "scale=1; $passed_tests * 100 / $total_tests" | bc)%"
        echo ""
        echo "Output Location: $OUTPUT_DIR"
        echo "================================================================================"
    } >> "$summary_file"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}TEST RUN COMPLETE${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "Total: $total_tests | ${GREEN}Passed: $passed_tests${NC} | ${RED}Failed: $failed_tests${NC}"
    echo ""
    echo "Outputs saved to: $OUTPUT_DIR"
    echo "Summary: $summary_file"
}

# Run main function
main "$@"

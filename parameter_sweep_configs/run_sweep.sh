#!/bin/bash
# Run parameter sweep experiments
#
# Usage:
#   ./run_sweep.sh                    # Run all sweep configurations
#   ./run_sweep.sh --dry-run          # Show what would be run without executing
#   ./run_sweep.sh CONFIG_PATH        # Run a specific configuration
#
# This script finds all params.jshc files in the sweep directories,
# merges them with the base config, and runs the simulation.

set -e

# Configuration
WORKSPACE="/workspace"
JAR="$WORKSPACE/jar/joshsim-fat-prod.jar"
MODEL="$WORKSPACE/vegetation_model.josh"
SIMULATION="Main"
BASE_PARAMS="$WORKSPACE/configs/params.jshc"
SCENARIO_CONFIG="$WORKSPACE/configs/fire_only.jshc"  # Use fire_only for sweep
FIRE_DATA="$WORKSPACE/preprocessed/fire_severity.jshd"
ELEVATION_DATA="$WORKSPACE/preprocessed/elevation.jshd"
RESULTS_DIR="$WORKSPACE/results/sweep"
SWEEP_DIR="$WORKSPACE/parameter_sweep_configs"

# Parse arguments
DRY_RUN=false
SPECIFIC_CONFIG=""

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        *)
            SPECIFIC_CONFIG="$arg"
            ;;
    esac
done

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function to merge configs (base + sweep overrides)
merge_configs() {
    local sweep_config="$1"
    local output_file="$2"

    # Start with base config
    cp "$BASE_PARAMS" "$output_file"

    # Append sweep parameters (which will override base values)
    echo "" >> "$output_file"
    echo "# === SWEEP OVERRIDES ===" >> "$output_file"
    # Only copy non-comment lines from sweep config
    grep -v "^#" "$sweep_config" >> "$output_file" || true
}

# Function to run a single configuration
run_config() {
    local config_path="$1"
    local config_dir=$(dirname "$config_path")
    local scenario_name=$(echo "$config_dir" | sed "s|$SWEEP_DIR/||")
    local safe_name=$(echo "$scenario_name" | tr '/' '_')
    local merged_config="$RESULTS_DIR/${safe_name}_merged.jshc"
    local output_file="$RESULTS_DIR/${safe_name}_results.csv"

    echo "========================================"
    echo "Running: $scenario_name"
    echo "========================================"

    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY RUN] Would merge: $BASE_PARAMS + $config_path"
        echo "  [DRY RUN] Would output: $output_file"
        return
    fi

    # Merge base config with sweep overrides
    merge_configs "$config_path" "$merged_config"

    # Run simulation
    cd "$WORKSPACE"
    java -jar "$JAR" run \
        --data "params.jshc=$merged_config" \
        --data "scenario.jshc=$SCENARIO_CONFIG" \
        --data "fire.jshd=$FIRE_DATA" \
        --data "elevation.jshd=$ELEVATION_DATA" \
        "$MODEL" "$SIMULATION"

    # Move output to results with scenario name
    # Model outputs to results/base/output_0.csv (hardcoded in model)
    if [ -f "$WORKSPACE/results/base/output_0.csv" ]; then
        mv "$WORKSPACE/results/base/output_0.csv" "$output_file"
        echo "  Output: $output_file"
    else
        echo "  WARNING: No output file generated"
    fi

    echo ""
}

# Main execution
echo "========================================"
echo "PARAMETER SWEEP RUNNER"
echo "========================================"
echo "Model: $MODEL"
echo "Base params: $BASE_PARAMS"
echo "Scenario: fire_only"
echo "Results: $RESULTS_DIR"
echo ""

if [ -n "$SPECIFIC_CONFIG" ]; then
    # Run specific configuration
    if [ -f "$SPECIFIC_CONFIG" ]; then
        run_config "$SPECIFIC_CONFIG"
    else
        echo "Error: Config not found: $SPECIFIC_CONFIG"
        exit 1
    fi
else
    # Find and run all configurations
    configs=$(find "$SWEEP_DIR" -name "params.jshc" -type f | sort)
    count=$(echo "$configs" | wc -l)

    echo "Found $count configurations to run"
    echo ""

    i=0
    for config in $configs; do
        i=$((i + 1))
        echo "[$i/$count]"
        run_config "$config"
    done
fi

echo "========================================"
echo "SWEEP COMPLETE"
echo "========================================"
echo "Results saved to: $RESULTS_DIR"

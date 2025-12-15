#!/usr/bin/env python3
"""
Generate .jshc configuration files from sweep_definitions.csv

Usage (command line):
    python generate_configs.py                    # Uses sweep_definitions.csv
    python generate_configs.py my_sweep.csv       # Uses custom CSV
    python generate_configs.py --clean            # Remove all generated configs

Usage (as module):
    from generate_configs import generate_sweep_configs, clean_generated_configs

    # Generate configs from default CSV
    configs = generate_sweep_configs()

    # Generate from custom CSV
    configs = generate_sweep_configs(csv_path='/path/to/sweep.csv')

    # Clean generated configs
    clean_generated_configs()
"""

import csv
import os
import sys
import shutil
from pathlib import Path
from datetime import datetime

# Module-level defaults
SCRIPT_DIR = Path(__file__).parent
DEFAULT_CSV = SCRIPT_DIR / "sweep_definitions.csv"
CONFIG_FILENAME = "params.jshc"

def parse_csv(csv_path: Path) -> list:
    """Parse CSV and return list of config dictionaries."""
    configs = []
    with open(csv_path, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            configs.append(dict(row))
    return configs

def extract_parameters(row: dict) -> tuple:
    """
    Extract path and parameters from a CSV row.
    Returns: (path, [(param_name, value, unit), ...])
    """
    path = row.pop('path')

    # Group parameters with their units
    params = []
    param_names = [k for k in row.keys() if not k.endswith('_unit')]

    for name in param_names:
        value = row[name]
        unit_key = f"{name}_unit"
        unit = row.get(unit_key, '')
        if value:  # Only include non-empty values
            params.append((name, value, unit))

    return path, params

def generate_jshc(params: list, path: str) -> str:
    """Generate .jshc file content from parameters."""
    lines = [
        f"# Auto-generated configuration for parameter sweep",
        f"# Path: {path}",
        f"# Generated: {datetime.now().isoformat()}",
        f"#",
        f"# This file contains ONLY the swept parameters.",
        f"# It should be used alongside the base params.jshc",
        f"#",
    ]

    for name, value, unit in params:
        if unit:
            lines.append(f"{name} = {value} {unit}")
        else:
            lines.append(f"{name} = {value}")

    return '\n'.join(lines) + '\n'

def write_config(base_dir: Path, path: str, content: str) -> Path:
    """Write config file to the appropriate nested directory."""
    config_dir = base_dir / path
    config_dir.mkdir(parents=True, exist_ok=True)

    config_path = config_dir / CONFIG_FILENAME
    config_path.write_text(content)

    return config_path

def clean_generated(base_dir: Path, csv_path: Path):
    """Remove all directories that were generated from the CSV."""
    if not csv_path.exists():
        print(f"CSV not found: {csv_path}")
        return

    configs = parse_csv(csv_path)
    removed = set()

    for row in configs:
        path = row.get('path', '')
        if path:
            # Get the top-level directory
            top_dir = base_dir / path.split('/')[0]
            if top_dir.exists() and str(top_dir) not in removed:
                shutil.rmtree(top_dir)
                removed.add(str(top_dir))
                print(f"Removed: {top_dir}")

    print(f"Cleaned {len(removed)} directories")


# ============================================================================
# Module API - for use from notebooks/other Python code
# ============================================================================

def generate_sweep_configs(csv_path=None, output_dir=None, verbose=True):
    """
    Generate .jshc configuration files from a sweep definitions CSV.

    Parameters:
        csv_path: Path to CSV file (default: sweep_definitions.csv in module dir)
        output_dir: Directory to write configs (default: same as CSV location)
        verbose: Print progress messages

    Returns:
        List of paths to generated config files
    """
    csv_path = Path(csv_path) if csv_path else DEFAULT_CSV
    output_dir = Path(output_dir) if output_dir else csv_path.parent

    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    configs = parse_csv(csv_path)
    if verbose:
        print(f"Generating {len(configs)} configurations from {csv_path.name}")

    generated_paths = []
    for row in configs:
        path, params = extract_parameters(row.copy())
        content = generate_jshc(params, path)
        config_path = write_config(output_dir, path, content)
        generated_paths.append(config_path)
        if verbose:
            print(f"  Created: {config_path.relative_to(output_dir)}")

    if verbose:
        print(f"\nDone. Generated {len(generated_paths)} config files.")

    return generated_paths


def clean_generated_configs(csv_path=None, output_dir=None):
    """
    Remove all directories generated from a sweep definitions CSV.

    Parameters:
        csv_path: Path to CSV file (default: sweep_definitions.csv in module dir)
        output_dir: Directory containing generated configs (default: same as CSV location)
    """
    csv_path = Path(csv_path) if csv_path else DEFAULT_CSV
    output_dir = Path(output_dir) if output_dir else csv_path.parent
    clean_generated(output_dir, csv_path)


def main():
    # Handle --clean flag
    if '--clean' in sys.argv:
        csv_path = DEFAULT_CSV
        if len(sys.argv) > 2 and sys.argv[1] != '--clean':
            csv_path = Path(sys.argv[1])
        clean_generated(SCRIPT_DIR, csv_path)
        return

    # Determine CSV path
    csv_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CSV

    if not csv_path.exists():
        print(f"Error: CSV file not found: {csv_path}")
        sys.exit(1)

    # Parse and generate
    configs = parse_csv(csv_path)
    print(f"Generating {len(configs)} configurations from {csv_path.name}")

    for row in configs:
        path, params = extract_parameters(row.copy())
        content = generate_jshc(params, path)
        config_path = write_config(SCRIPT_DIR, path, content)
        print(f"  Created: {config_path.relative_to(SCRIPT_DIR)}")

    print(f"\nDone. Generated {len(configs)} config files.")

if __name__ == '__main__':
    main()

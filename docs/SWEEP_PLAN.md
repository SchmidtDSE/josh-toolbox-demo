# Parameter Sweep Configuration Plan

This document describes the strategy for generating `.jshc` configuration files for parameter sweep experiments using the JOSH jar directly.

## Design Goals

1. **Interpretability** - Anyone can understand what parameters a run used by reading its folder path
2. **Traceability** - All parameter combinations defined in a single CSV file
3. **Simplicity** - Plain Python script, no templating engines or complex dependencies
4. **Reproducibility** - CSV + script = deterministic config generation

## Directory Structure

```
parameter_sweep_configs/
├── sweep_definitions.csv          # Defines all parameter combinations
├── generate_configs.py            # Script to create .jshc files from CSV
├── base_config.jshc               # Default values (optional, for reference)
│
└── [generated folders...]
    ├── high_seedling_survival/
    │   ├── low_elevation_bonus/
    │   │   └── config.jshc
    │   ├── medium_elevation_bonus/
    │   │   └── config.jshc
    │   └── high_elevation_bonus/
    │       └── config.jshc
    ├── medium_seedling_survival/
    │   └── .../
    └── low_seedling_survival/
        └── .../
```

## CSV Format: `sweep_definitions.csv`

Each row defines one configuration. Columns are:

| Column | Purpose |
|--------|---------|
| `path` | Folder path for this config (e.g., `high_seedling_survival/low_elevation_bonus`) |
| `<param_name>` | One column per parameter, header = variable name in .jshc |
| `<param_name>_unit` | Unit for the preceding parameter (e.g., `percent`, `m`, `K`) |

### Example CSV

```csv
path,survivalProbSeedling,survivalProbSeedling_unit,elevationBonus,elevationBonus_unit,fireFrequency,fireFrequency_unit
high_seedling_survival/low_elevation_bonus,80,percent,5,percent,0.1,count
high_seedling_survival/medium_elevation_bonus,80,percent,15,percent,0.1,count
high_seedling_survival/high_elevation_bonus,80,percent,30,percent,0.1,count
medium_seedling_survival/low_elevation_bonus,50,percent,5,percent,0.1,count
medium_seedling_survival/medium_elevation_bonus,50,percent,15,percent,0.1,count
medium_seedling_survival/high_elevation_bonus,50,percent,30,percent,0.1,count
low_seedling_survival/low_elevation_bonus,20,percent,5,percent,0.1,count
low_seedling_survival/medium_elevation_bonus,20,percent,15,percent,0.1,count
low_seedling_survival/high_elevation_bonus,20,percent,30,percent,0.1,count
```

## Generator Script: `generate_configs.py`

```python
#!/usr/bin/env python3
"""
Generate .jshc configuration files from sweep_definitions.csv

Usage:
    python generate_configs.py                    # Uses sweep_definitions.csv
    python generate_configs.py my_sweep.csv       # Uses custom CSV
    python generate_configs.py --clean            # Remove all generated configs
"""

import csv
import os
import sys
import shutil
from pathlib import Path
from datetime import datetime

SCRIPT_DIR = Path(__file__).parent
DEFAULT_CSV = SCRIPT_DIR / "sweep_definitions.csv"
CONFIG_FILENAME = "config.jshc"

def parse_csv(csv_path: Path) -> list[dict]:
    """Parse CSV and return list of config dictionaries."""
    configs = []
    with open(csv_path, newline='') as f:
        reader = csv.DictReader(f)
        for row in reader:
            configs.append(dict(row))
    return configs

def extract_parameters(row: dict) -> tuple[str, list[tuple[str, str, str]]]:
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

def generate_jshc(params: list[tuple[str, str, str]], path: str) -> str:
    """Generate .jshc file content from parameters."""
    lines = [
        f"# Auto-generated configuration",
        f"# Path: {path}",
        f"# Generated: {datetime.now().isoformat()}",
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
    removed = 0

    for row in configs:
        path = row.get('path', '')
        if path:
            # Get the top-level directory
            top_dir = base_dir / path.split('/')[0]
            if top_dir.exists():
                shutil.rmtree(top_dir)
                removed += 1
                print(f"Removed: {top_dir}")

    print(f"Cleaned {removed} directories")

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
```

## Running the Sweep

After generating configs, run all scenarios:

```bash
#!/bin/bash
# run_sweep.sh

JAR="jar/joshsim-fat.jar"
MODEL="model/simulation.josh"
SIMULATION="MySimulation"
REPLICATES=5

# Find all generated config files
find parameter_sweep_configs -name "config.jshc" | while read config; do
    # Extract scenario name from path (e.g., "high_seedling_survival/low_elevation_bonus")
    scenario=$(dirname "$config" | sed 's|parameter_sweep_configs/||')

    echo "========================================"
    echo "Running: $scenario"
    echo "========================================"

    java -jar "$JAR" run "$MODEL" "$SIMULATION" \
        --replicates="$REPLICATES" \
        --data params.jshc="$config" \
        --custom-tag scenario="$scenario"
done
```

## Workflow Summary

```
1. Define parameters    →  Edit sweep_definitions.csv
2. Generate configs     →  python generate_configs.py
3. Review configs       →  Browse folder structure, inspect .jshc files
4. Run sweep            →  ./run_sweep.sh
5. Clean up (optional)  →  python generate_configs.py --clean
```

## Adding New Parameters

1. Add two columns to CSV: `paramName` and `paramName_unit`
2. Fill in values for each row
3. Re-run `generate_configs.py`

## Adding New Scenarios

1. Add a new row to the CSV with a unique `path`
2. Re-run `generate_configs.py`

## Design Decisions

### Why nested folders instead of flat files?

- **Visual organization**: Easy to browse and understand at a glance
- **Path as metadata**: The folder path describes the scenario without opening any files
- **Grouping**: Related scenarios are physically grouped together
- **Scalability**: Works well even with hundreds of combinations

### Why CSV instead of YAML/JSON?

- **Spreadsheet-friendly**: Can edit in Excel/Google Sheets for large sweeps
- **Diff-friendly**: Easy to see changes in git
- **Simple parsing**: No external dependencies beyond Python stdlib
- **Tabular data**: Parameter sweeps are inherently tabular

### Why a single config.jshc per folder?

- **Consistency**: Always know where to find the config
- **Simplicity**: One file = one scenario
- **Path is the identifier**: No need to parse filenames

## Future Considerations

If sweeps become more complex, consider:

- **Templating**: Jinja2 templates for configs with shared boilerplate
- **Inheritance**: Base configs that scenario configs extend
- **Validation**: Script to verify all parameters are valid before running
- **Parallel execution**: GNU parallel or similar for running multiple scenarios concurrently

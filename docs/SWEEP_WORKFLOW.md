# Parameter Sweep Workflow

This document describes how to use the parameter sweep infrastructure to find optimal model configurations.

## Overview

The parameter sweep system allows systematic exploration of model parameters to find configurations that produce the expected ecological dynamics:

- **High elevation**: Native trees recover naturally, invasives suppressed
- **Low elevation**: Invasives dominate without intervention, natives struggle

## Quick Start

```bash
# 1. Generate sweep configurations
cd parameter_sweep_configs
pixi run python generate_configs.py

# 2. Run all configurations (takes ~10-15 minutes)
bash run_sweep.sh

# 3. Analyze results
# Open tuning_workflow.ipynb in Jupyter
```

## Directory Structure

```
parameter_sweep_configs/
├── sweep_definitions.csv      # Parameter combinations (edit this)
├── generate_configs.py        # Generates .jshc files from CSV
├── run_sweep.sh              # Runs all configurations
│
├── low_elev_effect/          # Generated config directories
│   ├── low_growth/
│   │   ├── low_threshold/
│   │   │   └── params.jshc
│   │   ├── med_threshold/
│   │   │   └── params.jshc
│   │   └── high_threshold/
│   │       └── params.jshc
│   ├── med_growth/...
│   └── high_growth/...
├── med_elev_effect/...
└── high_elev_effect/...

results/sweep/                 # Sweep output directory
├── <scenario>_merged.jshc    # Full config (base + overrides)
├── <scenario>_results.csv    # Simulation output
└── ...
```

## Parameters Being Swept

| Parameter | Description | Values | Effect |
|-----------|-------------|--------|--------|
| `elevationInvasiveGrowthReduction` | Growth rate reduction at high elevation | 10%, 20%, 30% | Higher = stronger elevation effect |
| `invasiveBaseGrowthRate` | Base invasive growth per year | 8%, 15%, 25% | Higher = faster invasive spread |
| `nativeEstablishmentThreshold` | Invasive cover blocking native establishment | 20%, 35%, 50% | Higher = natives tolerate more invasives |
| `seedlingElevationReduction` | Seedling mortality reduction at high elevation | 15%, 25%, 35% | Higher = better high-elev survival |
| `elevationInitialInvasiveReduction` | Initial invasive cover reduction at high elevation | 25%, 40%, 55% | Higher = less initial invasives at high elev |

### Parameter Combinations

The sweep tests **27 configurations** organized as:

- **3 elevation effect levels**: low (10%), medium (20%), high (30%)
- **3 growth rate levels**: low (8%), medium (15%), high (25%)
- **3 threshold levels**: low (20%), medium (35%), high (50%)

## Workflow Steps

### Step 1: Define Parameters

Edit `sweep_definitions.csv` to define parameter combinations:

```csv
path,elevationInvasiveGrowthReduction,elevationInvasiveGrowthReduction_unit,...
high_elev_effect/high_growth/med_threshold,30,percent,25,percent,...
```

**CSV Format:**
- `path`: Directory path for this configuration
- `<param>`: Parameter value
- `<param>_unit`: Unit for the parameter (percent, count, etc.)

### Step 2: Generate Configurations

```bash
cd parameter_sweep_configs
pixi run python generate_configs.py
```

This creates a `params.jshc` file in each path directory containing only the swept parameters.

**To clean up generated configs:**
```bash
pixi run python generate_configs.py --clean
```

### Step 3: Run the Sweep

```bash
bash run_sweep.sh
```

**Options:**
- `--dry-run`: Show what would run without executing
- `CONFIG_PATH`: Run a specific configuration only

**What the script does:**
1. Finds all generated `params.jshc` files
2. Merges each with the base `configs/params.jshc`
3. Runs the simulation with the merged config
4. Saves results to `results/sweep/`

### Step 4: Analyze Results

Open `tuning_workflow.ipynb` to:
1. Load all result files
2. Compute summary metrics per configuration
3. Score and rank configurations
4. Visualize parameter effects
5. Export the best configuration

## Evaluation Metrics

The tuning notebook scores configurations based on:

| Metric | Target | Description |
|--------|--------|-------------|
| `invasive_diff` | > 20% | Difference in invasive cover between low and high elevation |
| `tree_ratio` | > 2x | Ratio of trees at high vs low elevation |
| `high_invasive` | < 30% | Invasive cover at high elevation (should be suppressed) |
| `low_invasive` | > 50% | Invasive cover at low elevation (should be high) |

**Composite Score** (0-100):
- 25 points: `invasive_diff > 20%`
- 25 points: `tree_ratio > 2`
- 25 points: `high_invasive < 30%`
- 25 points: `low_invasive > 50%`

## Adding New Parameters

1. Add columns to `sweep_definitions.csv`:
   ```csv
   ...,newParam,newParam_unit
   ...,value,percent
   ```

2. Update `vegetation_model.josh` to read from config:
   ```josh
   myVar.init = config params.newParam else defaultValue
   ```

3. Regenerate configs:
   ```bash
   pixi run python generate_configs.py
   ```

## Adding New Scenarios

1. Add a row to `sweep_definitions.csv` with a unique `path`
2. Regenerate configs
3. Run the sweep

## Using the Best Configuration

After identifying the best configuration:

```bash
# Copy merged config to main params
cp results/sweep/best_scenario_merged.jshc configs/params.jshc

# Or manually update configs/params.jshc with the optimal values
```

## Troubleshooting

### "No results found"
- Ensure the sweep has been run: `bash run_sweep.sh`
- Check `results/sweep/` directory exists and contains `.csv` files

### "Config not found"
- Run `pixi run python generate_configs.py` to regenerate configs

### Simulations fail
- Check that preprocessing has been run (fire/elevation data exists)
- Validate the model: `pixi run java -jar jar/joshsim-fat-prod.jar validate vegetation_model.josh`

### All results look the same
- The elevation comparisons may not be working (Josh unit compatibility issue)
- Try more extreme parameter values
- Check that external data is in the correct units (0-100 percent scale)

## Files Reference

| File | Purpose |
|------|---------|
| `parameter_sweep_configs/sweep_definitions.csv` | Define parameter combinations |
| `parameter_sweep_configs/generate_configs.py` | Generate .jshc files |
| `parameter_sweep_configs/run_sweep.sh` | Run all configurations |
| `tuning_workflow.ipynb` | Analyze and visualize results |
| `results/sweep/*.csv` | Simulation outputs |
| `results/sweep/*_merged.jshc` | Complete configs used for each run |
| `results/base/*.csv` | Base scenario outputs (from demo_workflow) |

## Related Documentation

- `docs/SWEEP_PLAN.md` - Design rationale for the sweep system
- `docs/DEMO_PLANNING.md` - Expected ecological behaviors
- `CONTEXT.md` - Model technical details
- `WORKFLOW.md` - Manual tuning approach

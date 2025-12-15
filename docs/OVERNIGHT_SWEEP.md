# Overnight Parameter Sweep Plan

This document outlines a comprehensive diagnostic and parameter sweep to run overnight.

## Part 1: Diagnostics (Run First, ~5 min)

Before running the full sweep, run these diagnostics to understand the current state.

### 1.1 Check Data Scales

```bash
pixi run python << 'EOF'
import pandas as pd
import rasterio

print("="*60)
print("DATA SCALE DIAGNOSTICS")
print("="*60)

# Check source GeoTIFFs
print("\n1. SOURCE GEOTIFFS:")
for name in ['fire_severity', 'elevation']:
    with rasterio.open(f'/workspace/data/{name}.tif') as src:
        data = src.read(1)
        print(f"   {name}: {data.min():.2f} - {data.max():.2f}")

# Check what model outputs at step 0
print("\n2. MODEL OUTPUT AT STEP 0 (from most recent sweep):")
import glob
sweep_files = sorted(glob.glob('/workspace/results/sweep/*_results.csv'))
if sweep_files:
    df = pd.read_csv(sweep_files[0])
    step0 = df[df['step'] == 0]
    print(f"   fireSeverity: {step0['fireSeverity'].min():.3f} - {step0['fireSeverity'].max():.3f}")
    print(f"   elevation: {step0['elevation'].min():.3f} - {step0['elevation'].max():.3f}")
    print(f"   invasiveCover: {step0['invasiveCover'].min():.3f} - {step0['invasiveCover'].max():.3f}")
    print(f"   numAlive: {step0['numAlive'].min():.0f} - {step0['numAlive'].max():.0f}")
else:
    print("   No sweep results found")

# Check threshold behavior
print("\n3. THRESHOLD ANALYSIS:")
if sweep_files:
    print(f"   Patches with fireSeverity > 70: {(step0['fireSeverity'] > 70).sum()}")
    print(f"   Patches with fireSeverity > 0.70: {(step0['fireSeverity'] > 0.70).sum()}")
    print(f"   Patches with elevation > 60: {(step0['elevation'] > 60).sum()}")
    print(f"   Patches with elevation > 0.60: {(step0['elevation'] > 0.60).sum()}")
EOF
```

### 1.2 Test Single Run with Debug Export

Add temporary debug exports to the model and run once:

```bash
# First, backup the model
cp /workspace/vegetation_model.josh /workspace/vegetation_model.josh.bak

# Add debug exports (manually or via script)
pixi run python << 'EOF'
# Read model
with open('/workspace/vegetation_model.josh', 'r') as f:
    content = f.read()

# Add debug exports after the existing exports section
debug_exports = """
  # DEBUG EXPORTS (remove after diagnostics)
  export.baseInvasiveByFire.init = baseInvasiveByFire
  export.baseInvasive.init = baseInvasive
  export.elevationInvasiveReduction.init = elevationInvasiveReduction
  export.rawInvasiveInit.init = rawInvasiveInit
  export.clampedInvasiveInit.init = clampedInvasiveInit
"""

# Find the export section and add debug exports
if 'export.hasFire.init = hasFire' in content:
    content = content.replace(
        'export.hasFire.init = hasFire',
        'export.hasFire.init = hasFire' + debug_exports
    )
    with open('/workspace/vegetation_model.josh', 'w') as f:
        f.write(content)
    print("Added debug exports to model")
else:
    print("Could not find insertion point")
EOF

# Run a single test
pixi run java -jar jar/joshsim-fat-prod.jar run \
    --data params.jshc=configs/params.jshc \
    --data scenario.jshc=configs/fire_only.jshc \
    --data fire.jshd=preprocessed/fire_severity.jshd \
    --data elevation.jshd=preprocessed/elevation.jshd \
    vegetation_model.josh Main

# Analyze debug output
pixi run python << 'EOF'
import pandas as pd
df = pd.read_csv('/workspace/results/base/output_0.csv')
step0 = df[df['step'] == 0]

print("="*60)
print("DEBUG OUTPUT ANALYSIS")
print("="*60)

debug_cols = ['baseInvasiveByFire', 'baseInvasive', 'elevationInvasiveReduction',
              'rawInvasiveInit', 'clampedInvasiveInit', 'invasiveCover']

for col in debug_cols:
    if col in step0.columns:
        print(f"\n{col}:")
        print(f"   Range: {step0[col].min():.3f} - {step0[col].max():.3f}")
        print(f"   Mean: {step0[col].mean():.3f}")
    else:
        print(f"\n{col}: NOT FOUND")
EOF

# Restore original model
cp /workspace/vegetation_model.josh.bak /workspace/vegetation_model.josh
```

---

## Part 2: Large Parameter Sweep (~2-4 hours)

### 2.1 Expanded Sweep Definition

Create a new sweep with more parameter combinations and wider ranges.

```bash
pixi run python << 'EOF'
import csv
from pathlib import Path
from itertools import product

output_dir = Path('/workspace/parameter_sweep_configs')

# Define parameter ranges - EXPANDED
params = {
    'elevationInvasiveGrowthReduction': [5, 15, 30, 50],  # 4 levels
    'invasiveBaseGrowthRate': [5, 15, 30, 50],            # 4 levels
    'nativeEstablishmentThreshold': [20, 40, 60, 80],     # 4 levels
    'seedlingElevationReduction': [10, 25, 40],           # 3 levels
    'elevationInitialInvasiveReduction': [20, 40, 60],    # 3 levels
}

# Also test initial invasive cover multipliers
initial_invasive_multipliers = {
    'low': {'fireHighInvasive': 40, 'fireMedInvasive': 25, 'fireLowInvasive': 15},
    'med': {'fireHighInvasive': 60, 'fireMedInvasive': 40, 'fireLowInvasive': 25},
    'high': {'fireHighInvasive': 80, 'fireMedInvasive': 60, 'fireLowInvasive': 40},
}

# Generate combinations for main sweep (4x4x4 = 64 combos)
rows = []
for elev_red, growth, threshold in product(
    params['elevationInvasiveGrowthReduction'],
    params['invasiveBaseGrowthRate'],
    params['nativeEstablishmentThreshold']
):
    # Bundle seedling/initial reduction with elev_red level
    if elev_red <= 10:
        seed_red, init_red = 10, 20
        level = 'low'
    elif elev_red <= 25:
        seed_red, init_red = 25, 40
        level = 'med'
    else:
        seed_red, init_red = 40, 60
        level = 'high'

    path = f"sweep_{level}_elev/growth_{growth}/thresh_{threshold}"
    rows.append({
        'path': path,
        'elevationInvasiveGrowthReduction': elev_red,
        'elevationInvasiveGrowthReduction_unit': 'percent',
        'invasiveBaseGrowthRate': growth,
        'invasiveBaseGrowthRate_unit': 'percent',
        'nativeEstablishmentThreshold': threshold,
        'nativeEstablishmentThreshold_unit': 'percent',
        'seedlingElevationReduction': seed_red,
        'seedlingElevationReduction_unit': 'percent',
        'elevationInitialInvasiveReduction': init_red,
        'elevationInitialInvasiveReduction_unit': 'percent',
    })

# Write expanded sweep definitions
csv_path = output_dir / 'sweep_definitions_overnight.csv'
fieldnames = ['path'] + [f for p in params.keys() for f in [p, f'{p}_unit']]

with open(csv_path, 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)

print(f"Generated {len(rows)} configurations")
print(f"Saved to: {csv_path}")
print(f"\nEstimated runtime: {len(rows) * 20 / 60:.1f} minutes ({len(rows) * 20 / 3600:.1f} hours)")
EOF
```

### 2.2 Generate Configs and Run

```bash
cd /workspace/parameter_sweep_configs

# Generate configs from new CSV
pixi run python generate_configs.py sweep_definitions_overnight.csv

# Run the sweep (in background with logging)
nohup bash -c '
cd /workspace
RESULTS_DIR="/workspace/results/sweep_overnight"
mkdir -p "$RESULTS_DIR"

# Find all configs
configs=$(find parameter_sweep_configs -path "*/sweep_*" -name "params.jshc" | sort)
total=$(echo "$configs" | wc -l)
i=0

echo "Starting overnight sweep: $total configurations"
echo "Start time: $(date)"

for config in $configs; do
    i=$((i + 1))
    scenario=$(dirname "$config" | sed "s|parameter_sweep_configs/||" | tr "/" "_")
    merged="$RESULTS_DIR/${scenario}_merged.jshc"
    output="$RESULTS_DIR/${scenario}_results.csv"

    echo "[$i/$total] $(date +%H:%M:%S) Running: $scenario"

    # Merge configs
    cat configs/params.jshc > "$merged"
    echo "" >> "$merged"
    echo "# === SWEEP OVERRIDES ===" >> "$merged"
    grep -v "^#" "$config" >> "$merged"

    # Run simulation
    pixi run java -jar jar/joshsim-fat-prod.jar run \
        --data "params.jshc=$merged" \
        --data "scenario.jshc=configs/fire_only.jshc" \
        --data "fire.jshd=preprocessed/fire_severity.jshd" \
        --data "elevation.jshd=preprocessed/elevation.jshd" \
        vegetation_model.josh Main 2>&1

    # Move output
    if [ -f "results/base/output_0.csv" ]; then
        mv "results/base/output_0.csv" "$output"
    fi
done

echo "Sweep complete: $(date)"
' > /workspace/results/sweep_overnight.log 2>&1 &

echo "Sweep started in background. Monitor with:"
echo "  tail -f /workspace/results/sweep_overnight.log"
```

---

## Part 3: Alternative Hypothesis Tests

These test specific hypotheses about what might be wrong.

### 3.1 Test: Is the percent unit causing issues?

Create a version without percent units in comparisons:

```bash
pixi run python << 'EOF'
# Create a test model with raw numeric comparisons
with open('/workspace/vegetation_model.josh', 'r') as f:
    content = f.read()

# Replace "70 percent" with just "70" in fire severity comparisons
test_content = content.replace(
    'fireSeverity > 70 percent',
    'fireSeverity > 70'
).replace(
    'fireSeverity > 30 percent',
    'fireSeverity > 30'
).replace(
    'fireSeverity > 0 percent',
    'fireSeverity > 0'
)

with open('/workspace/vegetation_model_test_units.josh', 'w') as f:
    f.write(test_content)

print("Created test model: vegetation_model_test_units.josh")
EOF

# Run test
pixi run java -jar jar/joshsim-fat-prod.jar run \
    --data params.jshc=configs/params.jshc \
    --data scenario.jshc=configs/fire_only.jshc \
    --data fire.jshd=preprocessed/fire_severity.jshd \
    --data elevation.jshd=preprocessed/elevation.jshd \
    vegetation_model_test_units.josh Main

mv results/base/output_0.csv results/test_no_percent_units.csv

# Analyze
pixi run python -c "
import pandas as pd
df = pd.read_csv('results/test_no_percent_units.csv')
step0 = df[df['step'] == 0]
print('Test (no percent units):')
print(f'  Invasive cover: {step0[\"invasiveCover\"].min():.2f} - {step0[\"invasiveCover\"].max():.2f}')
"
```

### 3.2 Test: Force high initial invasive cover

Bypass the conditional logic entirely:

```bash
pixi run python << 'EOF'
with open('/workspace/vegetation_model.josh', 'r') as f:
    content = f.read()

# Replace the complex init with a simple fixed value
test_content = content.replace(
    'invasiveCover.init = clampedInvasiveInit',
    'invasiveCover.init = 50 percent  # FORCED HIGH FOR TEST'
)

with open('/workspace/vegetation_model_test_forced.josh', 'w') as f:
    f.write(test_content)

print("Created test model with forced 50% invasive cover")
EOF

pixi run java -jar jar/joshsim-fat-prod.jar run \
    --data params.jshc=configs/params.jshc \
    --data scenario.jshc=configs/fire_only.jshc \
    --data fire.jshd=preprocessed/fire_severity.jshd \
    --data elevation.jshd=preprocessed/elevation.jshd \
    vegetation_model_test_forced.josh Main

mv results/base/output_0.csv results/test_forced_invasive.csv

pixi run python -c "
import pandas as pd
df = pd.read_csv('results/test_forced_invasive.csv')
for step in [0, 10, 25, 50]:
    s = df[df['step'] == step]
    print(f'Step {step}: invasive={s[\"invasiveCover\"].mean():.1f}%, trees={s[\"numAlive\"].sum():.0f}')
"
```

### 3.3 Test: Different fire severity thresholds

Test if the issue is specifically with how 70/30 thresholds interact:

```bash
for threshold in 50 60 70 80 90; do
    pixi run python << EOF
with open('/workspace/vegetation_model.josh', 'r') as f:
    content = f.read()

content = content.replace(
    'fireSeverity > 70 percent',
    'fireSeverity > $threshold percent'
)

with open('/workspace/vegetation_model_test_thresh.josh', 'w') as f:
    f.write(content)
EOF

    pixi run java -jar jar/joshsim-fat-prod.jar run \
        --data params.jshc=configs/params.jshc \
        --data scenario.jshc=configs/fire_only.jshc \
        --data fire.jshd=preprocessed/fire_severity.jshd \
        --data elevation.jshd=preprocessed/elevation.jshd \
        vegetation_model_test_thresh.josh Main 2>/dev/null

    inv=$(pixi run python -c "
import pandas as pd
df = pd.read_csv('results/base/output_0.csv')
print(f'{df[df[\"step\"]==0][\"invasiveCover\"].mean():.2f}')
")
    echo "Threshold $threshold: mean invasive = $inv%"
done
```

---

## Part 4: Analysis Script (Run After Sweep Completes)

```bash
pixi run python << 'EOF'
import pandas as pd
import numpy as np
from pathlib import Path
import matplotlib.pyplot as plt

RESULTS_DIR = Path('/workspace/results/sweep_overnight')
result_files = list(RESULTS_DIR.glob('*_results.csv'))

print(f"Found {len(result_files)} result files")

if len(result_files) == 0:
    print("No results yet. Check sweep_overnight.log for progress.")
    exit()

# Load all results
all_data = []
for f in sorted(result_files):
    df = pd.read_csv(f)
    scenario = f.stem.replace('_results', '')
    df['scenario'] = scenario
    all_data.append(df)

data = pd.concat(all_data, ignore_index=True)
final = data[data['step'] == data['step'].max()].copy()
final['elev_zone'] = pd.cut(final['elevation'], bins=[0, 30, 60, 101], labels=['Low', 'Med', 'High'])

# Compute metrics
metrics = []
for scenario in final['scenario'].unique():
    sf = final[final['scenario'] == scenario]
    low_inv = sf[sf['elev_zone'] == 'Low']['invasiveCover'].mean()
    high_inv = sf[sf['elev_zone'] == 'High']['invasiveCover'].mean()
    low_trees = sf[sf['elev_zone'] == 'Low']['numAlive'].sum()
    high_trees = sf[sf['elev_zone'] == 'High']['numAlive'].sum()

    metrics.append({
        'scenario': scenario,
        'low_invasive': low_inv,
        'high_invasive': high_inv,
        'invasive_diff': low_inv - high_inv,
        'low_trees': low_trees,
        'high_trees': high_trees,
        'tree_ratio': high_trees / max(low_trees, 1),
    })

metrics_df = pd.DataFrame(metrics)

# Scoring
metrics_df['score'] = (
    (metrics_df['invasive_diff'] > 20).astype(int) * 25 +
    (metrics_df['tree_ratio'] > 2).astype(int) * 25 +
    (metrics_df['high_invasive'] < 30).astype(int) * 25 +
    (metrics_df['low_invasive'] > 50).astype(int) * 25
)

# Results summary
print("\n" + "="*60)
print("OVERNIGHT SWEEP RESULTS")
print("="*60)

print(f"\nScore distribution:")
print(metrics_df['score'].value_counts().sort_index(ascending=False))

print(f"\nTop 10 configurations:")
ranked = metrics_df.sort_values('score', ascending=False)
print(ranked[['scenario', 'score', 'invasive_diff', 'tree_ratio', 'low_invasive', 'high_invasive']].head(10).to_string())

print(f"\nKey metric ranges:")
print(f"  Invasive diff: {metrics_df['invasive_diff'].min():.1f}% to {metrics_df['invasive_diff'].max():.1f}%")
print(f"  Tree ratio: {metrics_df['tree_ratio'].min():.2f}x to {metrics_df['tree_ratio'].max():.2f}x")
print(f"  Low elev invasive: {metrics_df['low_invasive'].min():.1f}% to {metrics_df['low_invasive'].max():.1f}%")
print(f"  High elev invasive: {metrics_df['high_invasive'].min():.1f}% to {metrics_df['high_invasive'].max():.1f}%")

# Save summary
metrics_df.to_csv(RESULTS_DIR / 'overnight_summary.csv', index=False)
print(f"\nSaved summary to: {RESULTS_DIR / 'overnight_summary.csv'}")
EOF
```

---

## Quick Start Commands

Run these in order:

```bash
# 1. Run diagnostics first (5 min)
# Copy commands from Part 1 above

# 2. Start overnight sweep
cd /workspace/parameter_sweep_configs
pixi run python generate_configs.py sweep_definitions_overnight.csv
# Then run the nohup command from Part 2.2

# 3. Monitor progress
tail -f /workspace/results/sweep_overnight.log

# 4. In the morning, run analysis
# Copy commands from Part 4
```

## Expected Outcomes

After the overnight sweep, we should see one of:

1. **Some configs score well** → We found good parameters, use them
2. **All configs score poorly, but metrics vary** → Model works, just needs different parameter ranges
3. **All configs identical** → Fundamental model issue (unit scaling, logic error)
4. **Hypothesis tests reveal issue** → Specific fix identified

Good luck!

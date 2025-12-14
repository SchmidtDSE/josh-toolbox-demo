# File Organization Plan

## Problem Statement

The current project has accumulated files across multiple directories without clear conventions, leading to confusion about:
- Where raw inputs vs processed data should live
- Where simulation outputs vs analysis artifacts belong
- Which files are current vs experimental/obsolete
- What the canonical data flow is

---

## Current State (Problematic)

```
/workspace/
├── data/                    # Mixed: raw inputs + previews + experimental files
│   ├── elevation.tif
│   ├── elevation_scaled.tif        # Duplicate/experimental
│   ├── fire_severity.tif
│   ├── fire_severity_*.tif         # Multiple experimental versions
│   ├── *_preview.png               # Visualizations (don't belong here)
│   └── all_inputs_preview.png
│
├── preprocessed/            # Cluttered with experimental files
│   ├── elevation.jshd              # Current
│   ├── fire_severity.jshd          # Current
│   ├── fire_*.jshd                 # 15+ experimental/debug versions
│   └── removal_intensity.jshd
│
├── results/                 # Mixed: CSVs + PNGs + subdirectories
│   ├── baseline_0.csv
│   ├── fire_only_0.csv
│   ├── scenario_comparison.png     # Analysis output (wrong location?)
│   ├── spatial_difference_maps.png
│   ├── baseline/                   # Old run structure
│   └── all_scenarios_combined.csv
│
├── analysis/                # Underutilized
│   ├── figures/
│   ├── spatial_viz.py
│   └── visualizations.R
│
└── configs/                 # Clean, but params.jshc is getting large
    ├── params.jshc
    └── <scenario>.jshc
```

### Problems

1. **`data/` contains visualizations** - Preview PNGs should be in analysis output, not raw data
2. **`preprocessed/` has 20+ files** - Most are obsolete experiments
3. **`results/` mixes concerns** - Raw simulation output (CSV) + analysis figures (PNG)
4. **`analysis/` is underutilized** - Scripts exist but outputs go elsewhere
5. **No clear "current" vs "experimental"** - Hard to know which files matter

---

## Proposed Structure

```
/workspace/
├── data/                           # RAW INPUTS ONLY
│   ├── rasters/                    # GeoTIFF input rasters
│   │   ├── fire_severity.tif
│   │   └── elevation.tif
│   └── README.md                   # Document data sources
│
├── preprocessed/                   # JOSH-READY DATA ONLY
│   ├── fire_severity.jshd
│   ├── elevation.jshd
│   └── README.md                   # Document preprocessing steps
│
├── configs/                        # CONFIGURATION (unchanged)
│   ├── params.jshc                 # Shared ecological parameters
│   └── scenarios/                  # Scenario-specific configs
│       ├── baseline.jshc
│       ├── fire_only.jshc
│       ├── fire_seeding.jshc
│       ├── fire_removal.jshc
│       └── fire_both.jshc
│
├── results/                        # RAW SIMULATION OUTPUT ONLY
│   └── <scenario>_<replicate>.csv  # Direct Josh output
│
├── analysis/                       # ALL ANALYSIS ARTIFACTS
│   ├── figures/                    # Generated visualizations
│   │   ├── inputs/                 # Input data previews
│   │   │   ├── fire_severity.png
│   │   │   ├── elevation.png
│   │   │   └── combined_inputs.png
│   │   ├── timeseries/             # Time series plots
│   │   │   └── scenario_comparison.png
│   │   └── spatial/                # Spatial analysis
│   │       └── difference_maps.png
│   ├── summaries/                  # Aggregated data
│   │   ├── time_series_summary.csv
│   │   └── final_state_comparison.csv
│   └── scripts/                    # Analysis code
│       ├── generate_figures.py
│       └── spatial_analysis.py
│
├── archive/                        # EXPERIMENTAL/OLD FILES
│   ├── data/                       # Old input experiments
│   ├── preprocessed/               # Old JSHD experiments
│   └── results/                    # Old simulation runs
│
└── docs/                           # DOCUMENTATION
    ├── DEMO_PLANNING.md
    ├── ELEVATION_PLAN.md
    └── FILE_ORGANIZATION_PLAN.md
```

---

## Implementation Steps

### Phase 1: Archive Obsolete Files

```bash
# Create archive structure
mkdir -p archive/{data,preprocessed,results}

# Move experimental data files
mv data/elevation_scaled.tif archive/data/
mv data/fire_severity_*.tif archive/data/ 2>/dev/null
mv data/fire_severity.nc archive/data/
mv data/fire_severity_time.nc archive/data/

# Move experimental preprocessed files (keep only current)
mv preprocessed/fire_*.jshd archive/preprocessed/ 2>/dev/null
mv preprocessed/fire_severity.jshd preprocessed/  # Restore current

# Move old result subdirectories
mv results/baseline results/coldstart results/fire_* archive/results/ 2>/dev/null
```

### Phase 2: Reorganize Current Files

```bash
# Create new structure
mkdir -p data/rasters
mkdir -p configs/scenarios
mkdir -p analysis/figures/{inputs,timeseries,spatial}
mkdir -p analysis/summaries
mkdir -p analysis/scripts

# Move rasters to subdirectory
mv data/*.tif data/rasters/

# Move scenario configs
mv configs/baseline.jshc configs/scenarios/
mv configs/fire_*.jshc configs/scenarios/
mv configs/coldstart.jshc configs/scenarios/

# Move visualizations to analysis
mv data/*_preview.png analysis/figures/inputs/
mv results/*.png analysis/figures/
mv results/scenario_comparison.png analysis/figures/timeseries/
mv results/spatial_difference_maps.png analysis/figures/spatial/

# Move summaries
mv results/time_series_summary.csv analysis/summaries/
mv results/all_scenarios_combined.csv analysis/summaries/
```

### Phase 3: Update Code References

Files that need path updates:
1. `demo_workflow.ipynb` - Update all data/results paths
2. `vegetation_model.josh` - Update header comments
3. `analysis/spatial_viz.py` - Update input/output paths

Key changes:
```python
# OLD
FIRE_DATA = "preprocessed/fire_severity.jshd"
plt.savefig('data/fire_severity_preview.png')

# NEW
FIRE_DATA = "preprocessed/fire_severity.jshd"  # Unchanged
plt.savefig('analysis/figures/inputs/fire_severity.png')
```

### Phase 4: Add Documentation

Create `data/README.md`:
```markdown
# Input Data

## Rasters

- `fire_severity.tif` - Synthetic fire severity (0-1 scale)
- `elevation.tif` - Synthetic elevation gradient (0-100% scale)

## Data Sources

For the demo, these are synthetically generated. In production:
- Fire severity: Derived from Sentinel-2 RBR
- Elevation: From DEM (e.g., SRTM, ASTER)
```

Create `preprocessed/README.md`:
```markdown
# Preprocessed Data

Josh-ready binary files (.jshd) created by:
```bash
java -jar joshsim.jar preprocess model.josh Main input.tif 0 <unit> output.jshd
```

## Current Files

- `fire_severity.jshd` - From `data/rasters/fire_severity.tif` (ratio)
- `elevation.jshd` - From `data/rasters/elevation.tif` (percent)
```

---

## Naming Conventions

### Rasters
- `<variable>.tif` - Canonical input file
- `<variable>_<variant>.tif` - Experimental (should be in archive/)

### Preprocessed
- `<variable>.jshd` - Josh-ready format, matches raster name

### Results
- `<scenario>_<replicate>.csv` - Raw simulation output
- Pattern: `baseline_0.csv`, `fire_only_0.csv`

### Figures
- `<descriptive_name>.png` - Analysis outputs
- Organized by type: `inputs/`, `timeseries/`, `spatial/`

---

## Benefits

1. **Clear data flow**: `data/rasters/` → `preprocessed/` → `results/` → `analysis/`
2. **No mixed concerns**: Each directory has one purpose
3. **Easy cleanup**: Archive folder isolates experiments
4. **Reproducible**: Clear which files are canonical
5. **Discoverable**: Figures organized by analysis type

---

## Migration Checklist

- [ ] Create archive structure
- [ ] Move obsolete files to archive
- [ ] Create new subdirectories
- [ ] Move current files to correct locations
- [ ] Update `demo_workflow.ipynb` paths
- [ ] Update `vegetation_model.josh` comments
- [ ] Add README files to data/ and preprocessed/
- [ ] Test notebook runs end-to-end
- [ ] Delete archive/ after confirming nothing needed

# Context Summary: Josh Toolbox Demo Setup

## Project Overview

This is a **post-fire vegetation recovery demonstration** using the Josh simulation engine. The goal is to create a complete end-to-end workflow showing:
1. Generate synthetic fire severity and intervention rasters (Python)
2. Preprocess rasters for Josh (Java CLI)
3. Run simulations with different management scenarios
4. Analyze and visualize results (R/Python)

---

## ✅ Working Josh Patterns

### Verified Working Syntax

```josh
start simulation SimName
  grid.size = 10 m
  grid.low = 0.003 degrees latitude, 0 degrees longitude
  grid.high = 0 degrees latitude, 0.003 degrees longitude
  steps.low = 0 count
  steps.high = 50 count
  exportFiles.patch = "file:///absolute/path/to/output_{replicate}.csv"
end simulation

start patch Default
  # External data loading - variable name must match JSHD internal name
  fireSeverity.init = external data

  Organism.init = create Organism
  export.severity.init = fireSeverity
  export.count.step = count(Organism[Organism.state == "StateName"])
end patch

start organism Organism
  age.init = 0 year
  age.step = prior.age + 1 year
  state.init = "Initial"

  start state "Initial"
    state.step:if(current.age >= 10 years) = "NextState"
  end state
end organism
```

### Key Findings

1. **File export**: `file:///absolute/path.csv` (triple slash + absolute path)
2. **Template variables**: `{replicate}` works; avoid `{scenario}` unless passed via --custom-tag
3. **`prior.`**: Works inside **organisms** for temporal state (`prior.age`, `prior.cover`)
4. **State transitions**: `state.step:if(condition) = "NewState"` works in state blocks
5. **Organism counts**: `count(Organism[Organism.attr == value])` works in exports
6. **Grid coordinates**: WGS84 degrees work; grid.low = NW corner, grid.high = SE corner

### ⚠️ Critical External Data Fix (SOLVED)

**Root cause**: GeoTIFF bands are **0-indexed** in Josh's preprocess command. Using band `1` caused preprocessing to find no data.

**Working preprocess command**:
```bash
# IMPORTANT: Use band 0 (not 1) for GeoTIFF files!
java -jar joshsim-fat-prod.jar preprocess \
    model.josh SimName \
    data/input.tif 0 ratio \
    preprocessed/output.jshd \
    --timestep 0
```

**Working run command with external data**:
```bash
# Format: --data=<filename>.jshd=<path>
java -jar joshsim-fat-prod.jar run \
    model.josh SimName \
    "--data=data.jshd=/path/to/preprocessed/file.jshd"
```

**JSHD variable naming**:
- Preprocessing creates a variable called `data` inside the JSHD
- Josh code must reference it as `external data` (not `external fireSeverity`)

### Verify Preprocessing Worked

```bash
# Check JSHD has actual values (not 0 or default)
java -jar joshsim-fat-prod.jar inspectJshd \
    preprocessed/fire_severity.jshd data 0 15 15
# Should show actual value like: Value at (15, 15, 0): 0.943... ratio
```

---

## Current State

### Working Components

| Component | Status | Notes |
|-----------|--------|-------|
| Python raster generation | ✅ Working | Creates WGS84 GeoTIFFs with fire severity patterns |
| Josh preprocessing | ✅ Working | **Use band `0` and `--timestep 0`** |
| External data loading | ✅ Working | **Use `--data=data.jshd=/path`** |
| Josh simulation | ✅ Working | 50 years, 1000+ patches, exports CSV |
| vegetation_model_minimal.josh | ✅ Complete | Full demo with all features |

### Verified Results

Latest simulation run (vegetation_model_minimal.josh):
- **Fire severity range**: Spatially variable (0.01-0.95)
- **Initial trees**: ~5000 seedlings, ~2000 survive fire
- **Reproduction**: Adults produce seedlings starting Year 10
- **Invasive dynamics**: Cover grows from 40% to 80%, blocks recovery
- **51 time steps**: Years 0-50 post-fire

### Files

| File | Status | Description |
|------|--------|-------------|
| `minimal_states.josh` | ✅ Working | Reference model with state transitions |
| `vegetation_model.josh` | ✅ Working | Simplified model with external data |
| `vegetation_model_minimal.josh` | ✅ Complete | **Full demo model with all features** |
| `demo_workflow.ipynb` | ✅ Updated | Python data generation + preprocessing |
| `data/*.tif` | ✅ Generated | Fire severity, seeding, removal rasters |
| `preprocessed/*.jshd` | ✅ Created | Fire severity, seeding, removal (band 0) |

---

## Completed Features

### vegetation_model_minimal.josh now includes:

1. ✅ **External fire severity data** - Loads from preprocessed JSHD via `--data` flag
2. ✅ **Fire mortality** - Severity-based mortality applied at Year 0
3. ✅ **State machine** - Seedling → Juvenile (age 3) → Adult (age 10)
4. ✅ **Tree reproduction** - Adults produce 1 seedling/year (space/invasive limited)
5. ✅ **Invasive dynamics** - Logistic growth with post-fire bonus
6. ✅ **Management interventions** - Seeding boost and removal effort parameters

### Next Steps (Optional Enhancements)

Per DEMO_PLANNING.md, potential extensions:
1. Multiple scenario configurations (.jshc files)
2. 100 replicates per scenario for uncertainty analysis
3. Cold-start equilibration (1000 years pre-fire)
4. Spatial seed dispersal between patches

### Command Reference

```bash
# 1. Generate data (already done in demo_workflow.ipynb)

# 2. Preprocess all rasters
java -jar jar/joshsim-fat-prod.jar preprocess vegetation_model.josh Main \
    data/fire_severity.tif 0 ratio preprocessed/fire_severity.jshd --timestep 0

java -jar jar/joshsim-fat-prod.jar preprocess vegetation_model.josh Main \
    data/seeding_intensity.tif 0 count preprocessed/seeding_intensity.jshd --timestep 0

java -jar jar/joshsim-fat-prod.jar preprocess vegetation_model.josh Main \
    data/removal_intensity.tif 0 count preprocessed/removal_intensity.jshd --timestep 0

# 3. Run simulation with external data
java -jar jar/joshsim-fat-prod.jar run vegetation_model.josh Main \
    "--data=data.jshd=/workspace/preprocessed/fire_severity.jshd"

# 4. Verify results
head results/vegetation_0.csv
```

---

## Lessons Learned

1. **GeoTIFF bands are 0-indexed** - Always use band `0` for single-band GeoTIFFs
2. **JSHD variable is always `data`** - The preprocess command creates `data` variable, not the filename
3. **Use `--timestep 0`** for static spatial data
4. **Grid orientation matters** - grid.low = NW corner (top-left), grid.high = SE corner (bottom-right)
5. **External data path format** - `--data=data.jshd=/absolute/path/to/file.jshd`

---

*Last updated: Demo model complete with all core features*
*Status: Ready for scenario runs and analysis*

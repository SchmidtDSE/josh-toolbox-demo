# Project Context and Technical Notes

## Project Goal

Demonstrate post-fire vegetation recovery using the Josh simulation engine, showing:

> "High elevation areas will recover on their own; we should prioritize management in low elevation burned areas where invasives would otherwise dominate."

See `docs/DEMO_PLANNING.md` for full specification and `WORKFLOW.md` for the tuning workflow.

---

## Current Model State

### What's Working

| Feature | Status | Notes |
|---------|--------|-------|
| Fire mortality by severity | ✅ | Uses `:if/:elif` conditional syntax |
| Elevation affects invasive init | ✅ | High elevation starts with lower invasive cover |
| Stochastic tree survival | ✅ | Random rolls against mortality thresholds |
| Seeding intervention | ✅ | Adds trees at initialization |
| Removal intervention | ✅ | Reduces initial invasive cover |
| Config file loading | ✅ | Uses `scenario.jshc` and `params.jshc` |
| External data (fire, elevation) | ✅ | Preprocessed with band 0 |

### What's Simplified

| Feature | Status | Notes |
|---------|--------|-------|
| Invasive dynamics | ⚠️ Static | No growth over time (see below) |
| Tree reproduction | ⚠️ Limited | Adults produce seedlings but dynamics are simple |

---

## Known Issue: `prior.*` Access in Josh

### The Problem

Josh has issues with `prior.*` access at step 0 and in certain contexts. This causes dynamic calculations that depend on previous values to fail or produce unexpected results.

**Example of failing code:**
```josh
# This doesn't work reliably:
invasiveCover.step = prior.invasiveCover + growthRate * (1 - prior.invasiveCover)
```

**Observed behaviors:**
1. `prior.*` returns undefined/zero at step 0
2. Complex expressions using `prior.*` may not evaluate correctly
3. The issue is inconsistent - some `prior.*` usages work, others don't

### Current Workaround: Static Invasive Cover

The model uses **static invasive cover** set at initialization:

```josh
# Current implementation (simplified, no dynamics)
invasiveInitValue.init = clampedInvasiveInit
invasiveCover.init = clampedInvasiveInit

# Only changes via removal intervention
invasiveAfterRemoval.step = invasiveInitValue - activeRemoval
invasiveCover.step = 0 percent if invasiveAfterRemoval < 0 percent else invasiveAfterRemoval
```

**What this preserves:**
- Fire severity affects initial invasive cover (high fire → high invasives)
- Elevation affects initial invasive cover (high elevation → low invasives)
- Removal intervention reduces invasive cover

**What this loses:**
- Invasive growth over time
- Dynamic competition between trees and invasives
- Post-fire invasive expansion

### Potential Workarounds

#### Option 1: Step-Conditional Initialization

Use `:if` syntax to handle step 0 specially:

```josh
invasiveCover.step
  :if(meta.stepCount == 0) = invasiveInitValue
  :else = prior.invasiveCover + growthRate
```

**Status:** Untested - may work if `meta.stepCount` is available

#### Option 2: Lagged Variables

Store the previous value explicitly:

```josh
invasivePrev.init = invasiveInitValue
invasivePrev.step = prior.invasiveCover

invasiveCover.step = invasivePrev + growthRate * (1 - invasivePrev)
```

**Status:** Untested - circular reference may cause issues

#### Option 3: Discrete Time Bins

Pre-calculate invasive cover for discrete time periods:

```josh
# Calculate cover at key time points during init
invasiveYear0.init = initialCover
invasiveYear10.init = initialCover * growthFactor10
invasiveYear50.init = initialCover * growthFactor50

# Use appropriate value based on current step
invasiveCover.step
  :if(meta.stepCount < 10) = invasiveYear0
  :elif(meta.stepCount < 50) = invasiveYear10
  :else = invasiveYear50
```

**Status:** Untested - loses continuous dynamics but avoids `prior.*`

#### Option 4: External Preprocessing

Pre-calculate invasive trajectories in Python and load as external data:

```python
# Generate invasive cover for each timestep
for t in range(51):
    invasive_t = invasive_0 * (1 + growth_rate) ** t
    save_as_geotiff(invasive_t, f'invasive_t{t}.tif')
```

Then load the appropriate timestep in Josh based on `meta.stepCount`.

**Status:** Feasible but complex - requires many external files

---

## Josh Conditional Syntax Reference

### Single Condition (Ternary)
```josh
value.init = trueValue if condition else falseValue
```

### Multi-Branch Conditionals
Use `:if/:elif/:else` event handler modifiers:

```josh
fireMortality.init
  :if(here.fireSeverity > 0.7 and current.state == "Seedling") = 90 percent
  :elif(here.fireSeverity > 0.7 and current.state == "Juvenile") = 75 percent
  :elif(here.fireSeverity > 0.7 and current.state == "Adult") = 60 percent
  :elif(here.fireSeverity > 0.3 and current.state == "Seedling") = 60 percent
  :else = 0 percent
```

**Important:** Deeply nested ternaries do NOT work:
```josh
# THIS FAILS - don't use nested ternaries
value.init = a if cond1 else (b if cond2 else (c if cond3 else d))
```

---

## Config File System

### File Naming Convention

Josh looks for config files by name. The syntax `config namespace.variable` looks for:
- A file named `namespace.jshc` in the working directory
- A variable named `variable` (without prefix) inside that file

**Example:**
```josh
# In vegetation_model.josh
hasFire.init = config scenario.hasFire else 0 count
```

Requires `scenario.jshc` containing:
```
hasFire = 1 count
```

**Not:**
```
scenario.hasFire = 1 count  # Wrong - don't include namespace prefix
```

### Required Config Files

| File | Purpose |
|------|---------|
| `params.jshc` | Ecological parameters (mortality rates, thresholds) |
| `scenario.jshc` | Scenario settings (hasFire, seedingBoost, removalEffort) |

---

## GeoTIFF Preprocessing

### Band Numbering

GeoTIFF bands are **0-indexed** in Josh preprocessing:

```bash
# Correct - use band 0
pixi run java -jar jar/joshsim-fat-prod.jar preprocess \
  vegetation_model.josh Main \
  data/fire_severity.tif 0 "ratio" fire.jshd

# Wrong - band 1 returns zeros
pixi run java -jar jar/joshsim-fat-prod.jar preprocess \
  vegetation_model.josh Main \
  data/fire_severity.tif 1 "ratio" fire.jshd  # DON'T DO THIS
```

### Data Files

| File | Unit | Purpose |
|------|------|---------|
| `fire.jshd` | ratio | Fire severity (0-1) |
| `elevation.jshd` | ratio | Elevation gradient (0-1) |

---

## Running Simulations

### Basic Command
```bash
pixi run java -jar jar/joshsim-fat-prod.jar run vegetation_model.josh Main
```

Output goes to `results/output_0.csv` (rename after each scenario).

### Full Workflow
```bash
# 1. Update scenario.jshc for desired scenario
# 2. Run simulation
pixi run java -jar jar/joshsim-fat-prod.jar run vegetation_model.josh Main
# 3. Rename output
mv results/output_0.csv results/<scenario>_0.csv
# 4. Repeat for all scenarios
```

---

## Current Results Summary

| Scenario | Step 0 Trees | Step 50 Trees | Notes |
|----------|--------------|---------------|-------|
| baseline | 20,808 | 24,479 | No fire, healthy population |
| fire_only | 11,578 | 23,667 | 44% fire mortality, good recovery |
| fire_seeding | 23,209 | 24,479 | Extra initial trees from seeding |
| fire_removal | 11,655 | 23,693 | Slight improvement from removal |
| fire_both | 23,158 | 24,385 | Best recovery |

**Key observation:** Natural recovery is strong - fire_only reaches 97% of baseline by year 50. This may indicate fire mortality or invasive competition is too weak.

---

## Files Reference

| File | Purpose |
|------|---------|
| `vegetation_model.josh` | Main simulation model |
| `params.jshc` | Ecological parameters |
| `scenario.jshc` | Current scenario settings |
| `configs/*.jshc` | Saved scenario configurations |
| `analysis/visualizations.R` | R visualization script |
| `analysis/spatial_viz.py` | Python spatial visualization |
| `WORKFLOW.md` | Model tuning workflow |
| `docs/DEMO_PLANNING.md` | Original planning document |

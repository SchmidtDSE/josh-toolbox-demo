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
| Elevation affects invasive growth | ✅ | High elev: no growth, Low elev: fast growth |
| **Dynamic invasive growth** | ✅ | Logistic growth using `prior.invasiveCover` |
| Stochastic tree survival | ✅ | Random rolls against mortality thresholds |
| Tree reproduction | ✅ | Adults produce seedlings, blocked by high invasive cover |
| Seeding intervention | ✅ | Adds trees at initialization |
| Removal intervention | ✅ | Reduces invasive cover for 10 years |
| Config file loading | ✅ | Uses `scenario.jshc` and `params.jshc` |
| External data (fire, elevation) | ✅ | Preprocessed with band 0 |

### Key Ecological Pattern (Working!)

| Elevation | Invasive Growth | Tree Establishment | 50-Year Outcome |
|-----------|-----------------|-------------------|-----------------|
| **Low** | Fast (8%/year) | Blocked (>25% cover) | Trees collapse (204→6162 ratio vs high) |
| **High** | None (0%/year) | Allowed | Trees recover naturally |

**Management Insight**: Low elevation needs intervention; high elevation recovers on its own.

---

## RESOLVED: `prior.*` Access Works Correctly

### Previous Concern (Now Invalidated)

Earlier documentation suggested `prior.*` access had issues at step 0. **This has been tested and proven false.** The `prior.*` syntax works correctly for all use cases.

### What Actually Works

```josh
# This DOES work correctly:
stepCount.step = prior.stepCount + 1 count
invasiveCover.step = prior.invasiveCover + growthRate * remainingCapacity
```

**Test Results:**
- Linear growth: `10 + 5*step` ✅ Works
- Logistic growth: `prior + rate * (1 - prior)` ✅ Works
- Conditional using prior: ✅ Works
- Compound calculations: ✅ Works

### Current Implementation (Dynamic Invasive Growth)

The model now uses **dynamic invasive growth** with `prior.invasiveCover`:

```josh
# Logistic growth with elevation-dependent rate
remainingCapacity.step = (100 percent - prior.invasiveCover) / 100 percent
growthThisStep.step = clampedGrowthRate * remainingCapacity
rawInvasiveGrowth.step = prior.invasiveCover + growthThisStep - activeRemoval
invasiveCover.step = clamp(rawInvasiveGrowth, 0%, 100%)
```

This produces the correct ecological pattern:
- Low elevation: 10% → 98% over 50 years (fast growth)
- High elevation: 0% → 0% (no growth due to elevation reduction)

---

## Known Bug: JSHC Config Percent Values

### The Problem

Config files (`.jshc`) return raw numbers instead of percent-scaled values:

| Config File | Expected | Actual |
|-------------|----------|--------|
| `invasiveBaseGrowthRate = 8 percent` | 0.08 | 8.0 |
| `nativeEstablishmentThreshold = 25 percent` | 0.25 | 25.0 |

This breaks arithmetic and comparisons when mixing config values with inline percent literals.

### Current Workaround

Divide config percent values by 100 after loading:

```josh
# >>> JSHC_PERCENT_BUG WORKAROUND <<<
invasiveBaseGrowthRaw.init = config params.invasiveBaseGrowthRate else 8 count
invasiveBaseGrowth.init = invasiveBaseGrowthRaw / 100 count
# >>> END JSHC_PERCENT_BUG <<<
```

**Search for `JSHC_PERCENT_BUG` in the model to find all affected lines.**

When this bug is fixed upstream, remove the `/100` divisions.

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

### Total Tree Population

| Scenario | Step 0 Trees | Step 50 Trees | Change |
|----------|--------------|---------------|--------|
| baseline | 20,808 | 11,464 | -45% (invasive takeover at low elev) |
| fire_only | 11,682 | 6,666 | -43% (fire + invasive competition) |
| fire_seeding | 23,253 | 7,113 | -69% (seeding alone doesn't help) |
| fire_removal | 11,689 | 11,962 | +2% (removal prevents decline!) |
| fire_both | 23,335 | 12,483 | -47% (best absolute outcome) |

### Trees at Step 50 by Elevation

| Scenario | Low Elev | High Elev | Ratio |
|----------|----------|-----------|-------|
| fire_only | 204 | 6,162 | 30x |
| fire_removal | 681 | 9,862 | 14x |
| fire_both | 842 | 10,131 | 12x |

**Key Finding:** The model now demonstrates the target insight:
- High elevation recovers naturally (no intervention needed)
- Low elevation requires management (removal intervention = 3.3x more trees)
- Combined intervention provides best results at low elevation

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

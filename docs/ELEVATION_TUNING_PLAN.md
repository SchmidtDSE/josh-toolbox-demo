# Elevation Effect Tuning Plan

## Goal

Make the spatial comparison figures **immediately interpretable at a glance** by tuning elevation parameters so that:

> "High elevation areas will recover on their own; we should prioritize management in low elevation burned areas where invasives would otherwise dominate."

---

## Current State (Problematic)

### Observed Results

```
Elevation correlation (interventions should help more at LOW elevation):
  Fire Impact         : r = +0.02   # Near zero - no pattern!
  Seeding Benefit     : r = +0.00   # Near zero - no pattern!
  Removal Benefit     : r = +0.03   # Near zero - no pattern!
  Combined Benefit    : r = +0.01   # Near zero - no pattern!
```

### ROOT CAUSE: Spatial Mismatch

Looking at the current elevation map, the problem is obvious:

```
Current layout:
┌─────────────────────────────────┐
│ HIGH ELEV    │                  │
│ (plateau)    │   Medium elev    │
│    >60%      │                  │
├──────────────┤                  │
│              │                  │
│   Medium     │    FIRE IS       │
│   elev       │    HERE          │
│              │   (center)       │
│              │                  │
│              │      Low elev    │
└─────────────────────────────────┘

Problem: The high elevation plateau (NW corner) has almost NO OVERLAP
with the burned area (center). The elevation gradient runs AROUND the
fire, not THROUGH it!
```

**This is the #1 issue**: We need the elevation gradient to bisect the fire so that:
- Part of the burned area is HIGH elevation (will recover naturally)
- Part of the burned area is LOW elevation (needs intervention)

---

## PRIORITY FIXES (Do These First)

### Fix 1: Redesign Elevation to Intersect Fire

The elevation gradient should run **through the center of the fire**, not around it.

**Option A: N-S Gradient Through Center**
```
New layout:
┌─────────────────────────────────┐
│     HIGH ELEVATION (N edge)     │
│           >60%                  │
│─────────────────────────────────│
│     FIRE + HIGH ELEV            │  ← Fire overlaps high elev
│     (recovers naturally)        │
│ ─ ─ ─ ─ FIRE CENTER ─ ─ ─ ─ ─  │
│     FIRE + LOW ELEV             │  ← Fire overlaps low elev
│     (needs intervention)        │
│─────────────────────────────────│
│     LOW ELEVATION (S edge)      │
│           <30%                  │
└─────────────────────────────────┘
```

**Implementation** (in `demo_workflow.ipynb`):
```python
def generate_elevation(n_rows, n_cols, seed=None):
    """Generate N-S elevation gradient that intersects center fire."""
    if seed is not None:
        np.random.seed(seed)

    y, x = np.ogrid[:n_rows, :n_cols]
    y_norm = y / (n_rows - 1)

    # Simple N-S gradient: high at top (north), low at bottom (south)
    # This ensures the gradient runs THROUGH the center where fire is
    elevation = y_norm * 100  # 0% at bottom, 100% at top

    # Add subtle noise for realism
    noise = np.random.randn(n_rows, n_cols) * 3
    elevation = np.clip(elevation + noise, 0, 100)

    return elevation.astype(np.float32)
```

**Option B: Diagonal Gradient (NE-SW)**
```python
# Diagonal: high in NE corner, low in SW corner
# Fire in center will span the full gradient
elevation = (x_norm + y_norm) / 2 * 100
```

### Fix 2: Increase Grid Size by 1.5x

Larger grid = more spatial resolution = clearer patterns.

**Current**: 30 × 30 = 900 patches
**New**: 45 × 45 = 2,025 patches

**Files to update**:

1. `demo_workflow.ipynb` - Spatial configuration cell:
```python
# OLD
N_ROWS = 30
N_COLS = 30

# NEW
N_ROWS = 45
N_COLS = 45
```

2. `vegetation_model.josh` - Grid bounds:
```josh
# OLD
grid.low = 0.003 degrees latitude, 0 degrees longitude
grid.high = 0 degrees latitude, 0.003 degrees longitude

# NEW (1.5x larger)
grid.low = 0.0045 degrees latitude, 0 degrees longitude
grid.high = 0 degrees latitude, 0.0045 degrees longitude
```

3. Update visualization extents:
```python
# OLD
X_LOW, X_HIGH = 0, 300
Y_LOW, Y_HIGH = 0, 300

# NEW
X_LOW, X_HIGH = 0, 450
Y_LOW, Y_HIGH = 0, 450
```

---

## Implementation Checklist

### Step 1: Update Grid Size

- [ ] Edit `demo_workflow.ipynb`: Change `N_ROWS`, `N_COLS` to 45
- [ ] Edit `demo_workflow.ipynb`: Update `X_HIGH`, `Y_HIGH` to 450
- [ ] Edit `vegetation_model.josh`: Update `grid.low`/`grid.high` to 0.0045

### Step 2: Redesign Elevation Raster

- [ ] Replace `generate_elevation()` function with N-S gradient version
- [ ] Regenerate `data/elevation.tif`
- [ ] Regenerate `preprocessed/elevation.jshd`
- [ ] Verify elevation gradient runs through fire center

### Step 3: Regenerate Fire Severity

- [ ] Regenerate fire at center of larger grid (center = 22.5, 22.5)
- [ ] Increase `FIRE_SIGMA` proportionally (from 7 to ~10)
- [ ] Regenerate `data/fire_severity.tif`
- [ ] Regenerate `preprocessed/fire_severity.jshd`

### Step 4: Run and Evaluate

- [ ] Run all 5 scenarios
- [ ] Generate spatial difference maps
- [ ] Check elevation correlations (target: |r| > 0.15)
- [ ] Visual inspection: gradient should be visible in difference maps

---

## Secondary Tuning (After Spatial Fixes)

Only proceed to these if spatial fixes alone don't produce clear patterns:

### Parameters to Tune

### Location: `configs/params.jshc`

```bash
# =============================================================================
# ELEVATION EFFECTS - KEY TUNING PARAMETERS
# =============================================================================

# Invasive growth reduction at HIGH elevation
# CURRENT: 5 percent (too weak)
# EFFECT: Reduces invasive annual growth rate at high elevation
invasiveElevationReduction = 5 percent

# Seedling mortality reduction at HIGH elevation
# CURRENT: 20 percent (moderate)
# EFFECT: At high elev, seedling mortality drops from 40% to 20%
seedlingElevationReduction = 20 percent

# Juvenile mortality reduction at HIGH elevation
# CURRENT: 6 percent (too weak)
# EFFECT: At high elev, juvenile mortality drops from 15% to 9%
juvenileElevationReduction = 6 percent
```

### Location: `vegetation_model.josh` (lines ~106-124)

```josh
# Zone thresholds - CRITICAL for pattern visibility
highElevationThreshold.init = 60 percent    # Patches above this get full bonus
mediumElevationThreshold.init = 30 percent  # Patches 30-60% get half bonus

# Medium elevation effects (currently half of high)
invasiveMediumReduction.init = 2 percent
seedlingMediumReduction.init = 10 percent
juvenileMediumReduction.init = 3 percent
```

---

## Tuning Strategy

### Approach 1: Stronger Elevation Effects (Recommended First)

Dramatically increase the effect sizes to make patterns obvious, then dial back if too extreme.

```bash
# configs/params.jshc - AGGRESSIVE VALUES
invasiveElevationReduction = 8 percent      # Was 5%
seedlingElevationReduction = 35 percent     # Was 20% - BIG INCREASE
juvenileElevationReduction = 12 percent     # Was 6%
```

**Expected outcome**: High elevation patches should have ~50% lower seedling mortality (40% → 5%) compared to low elevation. This should create visible survival gradients.

### Approach 2: Adjust Zone Thresholds

If elevation distribution doesn't match thresholds, patterns won't emerge.

```
Current elevation distribution:
  High (>60%): 156 patches (17%)
  Medium (30-60%): 463 patches (51%)
  Low (<30%): 281 patches (31%)
```

Option A: **Lower thresholds** to put more area in "high" zone:
```josh
highElevationThreshold.init = 50 percent    # Was 60%
mediumElevationThreshold.init = 25 percent  # Was 30%
```

Option B: **Raise thresholds** to concentrate high-elevation bonus:
```josh
highElevationThreshold.init = 70 percent    # Was 60%
mediumElevationThreshold.init = 40 percent  # Was 30%
```

### Approach 3: Modify Elevation Raster

Create a more dramatic elevation gradient with clearer zones.

```python
# In demo_workflow.ipynb - generate_elevation()

# CURRENT: Gentle gradient + plateau
plateau_boost = 0.3  # 30% boost

# OPTION A: Steeper gradient
# Increase contrast between NW and SE
gradient = (1 - x_norm) * 0.7 + y_norm * 0.7  # Was 0.5

# OPTION B: Larger plateau
plateau_fraction = 0.5  # Was 0.4
plateau_boost = 0.4     # Was 0.3

# OPTION C: Step function (most dramatic)
# Create distinct elevation bands instead of gradient
elevation = np.zeros((N_ROWS, N_COLS))
elevation[y_norm > 0.66] = 90  # Top third = high
elevation[(y_norm > 0.33) & (y_norm <= 0.66)] = 50  # Middle = medium
elevation[y_norm <= 0.33] = 10  # Bottom third = low
```

### Approach 4: Increase Baseline Invasive Pressure

If invasives aren't a threat, elevation effects don't matter. Increase invasive competitiveness.

```bash
# configs/params.jshc
invasiveBaseGrowthRate = 5 percent    # Was 3 percent
postFireGrowthBonus = 8 percent       # Was 5 percent
establishmentThreshold = 40 percent   # Was 50 percent (stricter)
```

### Approach 5: Look at Earlier Time Steps

The model may show strong patterns early that disappear by Year 50.

```python
# In analysis, examine Year 10-20 instead of Year 50
ANALYSIS_YEAR = 20  # Instead of max_step

# Or output only specific steps to reduce file size
# In Josh command:
--output-steps=0,10,20,30,40,50
```

---

## Recommended Tuning Sequence

### Round 1: Aggressive Parameter Increase

```bash
# configs/params.jshc
invasiveElevationReduction = 8 percent
seedlingElevationReduction = 35 percent
juvenileElevationReduction = 12 percent
```

Run and check:
- Elevation correlation should be r > |0.2|
- Visual pattern should be obvious

### Round 2: If Still Weak, Modify Elevation Raster

```python
# Increase gradient steepness
gradient = (1 - x_norm) * 0.7 + y_norm * 0.7
plateau_boost = 0.4
```

### Round 3: If Invasives Not a Factor, Increase Pressure

```bash
invasiveBaseGrowthRate = 5 percent
postFireGrowthBonus = 8 percent
```

### Round 4: Fine-tune Zone Thresholds

Adjust based on where patterns appear in the maps.

---

## Testing Protocol

After each parameter change:

1. **Regenerate elevation** (if raster changed):
   ```bash
   pixi run python -c "..." # Elevation generation code
   pixi run java -jar ... preprocess ... elevation.tif ...
   ```

2. **Run scenarios**:
   ```bash
   for scenario in baseline fire_only fire_seeding fire_removal fire_both; do
       pixi run java -jar ... run ... $scenario ...
   done
   ```

3. **Generate analysis**:
   ```bash
   pixi run python -c "..." # Spatial analysis code
   ```

4. **Check metrics**:
   - Elevation correlation (target: r > |0.2|)
   - Visual inspection of difference maps
   - Final tree counts by elevation zone

---

## Success Criteria

### Quantitative
- [ ] Fire impact correlation with elevation: r > +0.15 (fire hurts more at low elevation)
- [ ] Seeding benefit correlation with elevation: r < -0.15 (seeding helps more at low elevation)
- [ ] Removal benefit correlation with elevation: r < -0.15 (removal helps more at low elevation)
- [ ] Clear difference in final tree counts between high/low elevation zones

### Qualitative
- [ ] Spatial difference maps show obvious NW-SE gradient
- [ ] High severity + low elevation areas (SE quadrant) show most intervention benefit
- [ ] High elevation areas (NW plateau) show recovery regardless of intervention
- [ ] A non-expert can interpret the figure in <10 seconds

---

## Parameter Reference Table

| Parameter | Location | Current | Conservative | Aggressive |
|-----------|----------|---------|--------------|------------|
| `invasiveElevationReduction` | params.jshc | 5% | 6% | 8% |
| `seedlingElevationReduction` | params.jshc | 20% | 25% | 35% |
| `juvenileElevationReduction` | params.jshc | 6% | 8% | 12% |
| `highElevationThreshold` | model.josh | 60% | 55% | 50% |
| `mediumElevationThreshold` | model.josh | 30% | 25% | 20% |
| `plateau_boost` | notebook | 0.3 | 0.35 | 0.4 |
| `gradient_strength` | notebook | 0.5 | 0.6 | 0.7 |
| `invasiveBaseGrowthRate` | params.jshc | 3% | 4% | 5% |

---

## Quick Start Commands

```bash
# 1. Edit params.jshc with aggressive values
# 2. Run full workflow:

# Preprocess (if elevation changed)
pixi run java -jar jar/joshsim-fat-prod.jar preprocess \
    vegetation_model.josh Main \
    data/elevation.tif 0 percent \
    preprocessed/elevation.jshd --timestep 0

# Run all scenarios
for s in baseline fire_only fire_seeding fire_removal fire_both; do
    pixi run java -jar jar/joshsim-fat-prod.jar run \
        --data "params.jshc=configs/params.jshc" \
        --data "scenario.jshc=configs/${s}.jshc" \
        --data "fire.jshd=preprocessed/fire_severity.jshd" \
        --data "elevation.jshd=preprocessed/elevation.jshd" \
        vegetation_model.josh Main
    mv results/output_0.csv results/${s}_0.csv
done

# Generate analysis (run Python analysis script)
pixi run python analysis/scripts/generate_figures.py
```

---

## Notes

- The zone-based approach (vs continuous gradient) was necessary due to Josh unit system limitations
- If continuous gradients are strongly desired, may need Josh engine enhancement
- Current model converges to stable state by Year 50; consider shorter simulations for visible dynamics

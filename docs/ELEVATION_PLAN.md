# Elevation-Driven Spatial Patterns: Implementation Plan

## Goal

Make the spatial comparison figures **immediately interpretable at a glance** by introducing elevation as a driver of ecological dynamics. The current figures are too patchy due to stochasticity - we need smooth, obvious patterns that communicate:

> "High elevation areas will recover on their own; we should prioritize management in low elevation burned areas where invasives would otherwise dominate."

---

## The Problem with Current Output

The current spatial difference maps show scattered red/green patches because:
1. **Stochasticity dominates**: Each patch has independent random mortality/reproduction
2. **No spatial structure**: All patches have identical parameters
3. **Fire is the only gradient**: Severity creates some pattern, but it's circular and doesn't tell a "prioritization" story

What we need: **A second gradient (elevation) that creates clear zones** where outcomes differ predictably.

---

## Proposed Solution: Elevation as Ecological Driver

### 1. Elevation Raster Design

Create `elevation.tif` with a **gradient + step change**:

```
High elevation (NW corner)
    ↑
    │   ┌─────────────┐
    │   │ Plateau     │  <- Sudden step up
    │   │ (high elev) │
    │   └─────────────┘
    │
    └──────────────────→ Low elevation (SE corner)
```

**Implementation:**
```python
# Base gradient: NW high, SE low
gradient = (1 - x/N_COLS) * 0.5 + (1 - y/N_ROWS) * 0.5

# Add plateau in upper portion (sudden step)
plateau_mask = (y > N_ROWS * 0.6) & (x < N_COLS * 0.6)
elevation = gradient + plateau_mask * 0.3

# Normalize to 0-1
elevation = (elevation - elevation.min()) / (elevation.max() - elevation.min())
```

This creates:
- **Low elevation zone** (SE): Where invasives thrive, trees struggle
- **High elevation zone** (NW plateau): Where trees do well, invasives are suppressed
- **Transition zone**: Where fire + management interactions are most visible

### 2. Ecological Mechanisms

#### Invasive Grass Response to Elevation
- **Low elevation**: Faster growth, higher carrying capacity
- **High elevation**: Slower growth, climate-limited

```josh
# In patch, modify growth rate based on elevation
elevationFactor.init = 1 - 0.7 * (external data)  # 1.0 at low elev, 0.3 at high
invasiveGrowthRate.step = baseGrowthRate * elevationFactor
```

#### Native Tree Response to Elevation
- **Low elevation**: Higher seedling mortality (drought/heat stress)
- **High elevation**: Better survival, but already tested by fire

```josh
# In organism Seedling state, modify mortality
elevationBonus.step = 0.3 * here.elevation  # Up to 30% mortality reduction at high elev
effectiveMortality.step = baseMortality * (1 - elevationBonus)
```

### 3. Expected Outcomes by Zone

| Zone | Fire Severity | Elevation | Without Management | With Management |
|------|---------------|-----------|-------------------|-----------------|
| **A: SE burned** | High | Low | Invasive takeover | Management critical |
| **B: Center burned** | High | Medium | Slow recovery | Management helps |
| **C: NW burned** | Moderate | High | Natural recovery | Management less needed |
| **D: Unburned edges** | None | Variable | Stable | N/A |

### 4. Visual Story

The spatial difference maps should show:

**Fire Impact (fire_only - baseline):**
- Red concentrated in low elevation burned areas
- Less red in high elevation areas (trees more resilient)

**Seeding Benefit (fire_seeding - fire_only):**
- Green concentrated in moderate-low elevation burned areas
- Little effect at high elevation (would recover anyway)
- Little effect at very low elevation (invasives still win)

**Removal Benefit (fire_removal - fire_only):**
- Strong green in low elevation burned areas
- This is where invasives would dominate without removal

**Combined Benefit:**
- Strongest green in low-moderate elevation burned areas
- Clear message: "This is where to focus resources"

---

## Implementation Steps

### Phase 1: Generate Elevation Data
1. Create `generate_elevation()` function with gradient + plateau
2. Save as `data/elevation.tif`
3. Preprocess to `preprocessed/elevation.jshd`
4. Visualize to verify pattern makes sense

### Phase 2: Modify Josh Model
1. Add `elevation.init = (external data)` to patch
2. Modify `invasiveCover` growth calculation to include elevation factor
3. Modify seedling mortality in organism to include elevation bonus
4. Keep adult/juvenile mortality unchanged (fire is main driver)

### Phase 3: Parameter Tuning
This is the critical step - we need to find parameters that produce clear visual patterns.

**Parameters to tune:**
| Parameter | Range | Effect |
|-----------|-------|--------|
| `invasiveElevationSensitivity` | 0.3-0.8 | How much elevation suppresses invasive growth |
| `seedlingElevationBonus` | 0.1-0.4 | How much elevation helps seedling survival |
| `seedingBoost` | 4-12 count | Number of seedlings added |
| `removalEffort` | 8-20 percent | Invasive removal rate |

**Tuning approach:**
1. Start with strong effects (high sensitivity values)
2. Run all 5 scenarios
3. Generate spatial difference maps
4. Evaluate: Are patterns clear? Is the story obvious?
5. Adjust parameters and repeat

**Success criteria:**
- Fire impact clearly concentrated in low elevation areas
- Seeding benefit visible in moderate elevation burned zones
- Removal benefit strongest in low elevation burned zones
- Combined shows clear "priority zone" in low-moderate elevation fire areas

### Phase 4: Final Visualization
1. Update spatial comparison figure
2. Add elevation contours to show the gradient
3. Consider adding a "management priority" composite figure

---

## Model Changes Summary

### New Files
- `data/elevation.tif` - Elevation raster
- `preprocessed/elevation.jshd` - Preprocessed for Josh

### vegetation_model.josh Changes

```josh
# In patch:
elevation.init = (external data)  # From elevation.jshd

# Modify invasive growth (add after current growth rate calculation)
elevationFactor.step = 1 - config params.invasiveElevationSensitivity * elevation
adjustedGrowthRate.step = growthRate * elevationFactor

# In organism NativeTree, Seedling state:
elevationBonus.step = config params.seedlingElevationBonus * here.elevation
adjustedMortality.step = totalMortality * (1 - elevationBonus)
```

### New Config Parameters (params.jshc)
```
# Elevation effects
invasiveElevationSensitivity = 0.6
seedlingElevationBonus = 0.25
```

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Patterns still too noisy | Increase elevation sensitivity; consider smoothing stochasticity |
| Effects too strong (unrealistic) | This is a toy model - clarity > realism for demo purposes |
| Fire pattern conflicts with elevation | Position fire center in transition zone for max effect |
| Parameter tuning takes too long | Start with extreme values, then dial back |

---

## Alternative: Reduce Stochasticity Directly

If elevation doesn't create clear enough patterns, we could also:
1. **Increase replicates and average**: Run 10+ replicates, show mean
2. **Reduce mortality variance**: Make mortality more deterministic
3. **Spatial smoothing**: Post-process results with spatial averaging

However, elevation is preferred because it tells a better story and is ecologically motivated.

---

## Timeline Estimate

1. **Phase 1** (Elevation data): 30 min
2. **Phase 2** (Model changes): 1 hour
3. **Phase 3** (Parameter tuning): 1-2 hours (iterative)
4. **Phase 4** (Visualization): 30 min

Total: ~3-4 hours

---

## Questions for User

1. Should the plateau be in the NW (creating a "refugium" story) or elsewhere?
2. How extreme should the elevation effects be? (Realism vs. visual clarity)
3. Should we also reposition the fire center to maximize the elevation interaction?
4. Do we want to show the elevation gradient in the final figures (as contours)?

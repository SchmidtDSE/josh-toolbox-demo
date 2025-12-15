# Model Tuning Workflow

This document describes the iterative workflow for tuning the post-fire vegetation recovery model to achieve the goals outlined in `docs/DEMO_PLANNING.md`.

## Goal Reminder

The model should demonstrate:
> "High elevation areas will recover on their own; we should prioritize management in low elevation burned areas where invasives would otherwise dominate."

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Define Hypothesis                                           │
│     "What ecological behavior should we see?"                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Run Scenarios                                               │
│     baseline, fire_only, fire_seeding, fire_removal, fire_both  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Analyze Results                                             │
│     - Compare tree populations across scenarios                 │
│     - Check spatial patterns (elevation × fire severity)        │
│     - Examine intervention effectiveness                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. Identify Gaps                                               │
│     Does the model show the expected ecological dynamics?       │
│     - If YES → Document and finalize                            │
│     - If NO → Adjust parameters and repeat                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. Adjust Parameters (in configs/params.jshc)                  │
│     - Fire mortality rates                                      │
│     - Invasive growth dynamics                                  │
│     - Elevation effects                                         │
│     - Intervention intensities                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              └──────────► (repeat from step 2)
```

## Quick Commands

### Run All Scenarios
```bash
# Update scenario.jshc for each scenario and run
for scenario in baseline fire_only fire_seeding fire_removal fire_both; do
  cat > scenario.jshc << EOF
hasFire = $([ "$scenario" = "baseline" ] && echo "0" || echo "1") count
seedingBoost = $(echo "$scenario" | grep -q "seeding\|both" && echo "8" || echo "0") count
removalEffort = $(echo "$scenario" | grep -q "removal\|both" && echo "12" || echo "0") percent
EOF
  pixi run java -jar jar/joshsim-fat-prod.jar run vegetation_model.josh Main
  mv results/output_0.csv results/${scenario}_0.csv
done
```

### Regenerate Figures
```bash
pixi run python analysis/spatial_viz.py
pixi run visualize
```

### Quick Results Check
```bash
pixi run python -c "
import pandas as pd
scenarios = ['baseline', 'fire_only', 'fire_seeding', 'fire_removal', 'fire_both']
for s in scenarios:
    df = pd.read_csv(f'results/{s}_0.csv')
    step0 = df[df['step']==0]['numAlive'].sum()
    step50 = df[df['step']==50]['numAlive'].sum()
    print(f'{s:15s}: {step0:6.0f} → {step50:6.0f} trees')
"
```

## Key Parameters to Tune

### 1. Fire Mortality (`vegetation_model.josh`)

Located in the `NativeTree` organism, using `:if/:elif` syntax:

```josh
fireMortality.init
  :if(here.fireSeverity > 0.7 and current.state == "Seedling") = 90 percent
  :elif(here.fireSeverity > 0.7 and current.state == "Adult") = 60 percent
  # ... etc
```

**Tuning guidance:**
- Higher mortality → More dramatic fire impact, slower recovery
- Lower mortality → Faster natural recovery, less need for intervention

### 2. Invasive Dynamics (`vegetation_model.josh`)

Currently **static** due to `prior.*` access issues (see CONTEXT.md). The invasive cover is set at initialization and only changes via removal intervention.

**Key parameters in `configs/params.jshc`:**
```
invasiveBaseGrowthRate = 15 percent    # Annual growth rate
postFireGrowthBonus = 15 percent       # Extra growth after fire
postFireBonusDuration = 15 count       # Years of bonus growth
treeSuppression = 0.1                  # How much trees suppress invasives
```

### 3. Elevation Effects (`configs/params.jshc`)

```
# Initial invasive reduction at high elevation
elevationInitialInvasiveReduction = 50 percent
elevationMediumInvasiveReduction = 25 percent

# Seedling survival bonus at high elevation
seedlingElevationReduction = 35 percent
seedlingMediumElevationReduction = 15 percent
```

**Tuning guidance:**
- Increase `elevationInitialInvasiveReduction` → Stronger elevation gradient for invasives
- Increase `seedlingElevationReduction` → Better tree survival at high elevation

### 4. Intervention Intensities (`configs/*.jshc`)

```
seedingBoost = 8 count        # Trees added per patch
removalEffort = 12 percent    # Invasive cover reduction
```

## Expected Ecological Patterns

When properly tuned, the model should show:

| Pattern | Indicator | Current Status |
|---------|-----------|----------------|
| Fire kills trees | Step 0: fire scenarios have fewer trees than baseline | ✅ Working |
| Elevation affects invasives | High elevation has lower invasive cover | ✅ Working |
| Elevation affects recovery | High elevation recovers faster | ⚠️ Subtle |
| Invasives compete with trees | High invasive cover reduces seedling establishment | ⚠️ Static |
| Seeding helps recovery | fire_seeding > fire_only at step 50 | ✅ Working |
| Removal helps recovery | fire_removal > fire_only at step 50 | ⚠️ Minimal |
| Combined intervention best | fire_both > all other fire scenarios | ✅ Working |

## Common Issues and Solutions

### Issue: All scenarios look the same
**Cause:** Fire not being applied (hasFire=0 in all configs)
**Solution:** Check `scenario.jshc` has `hasFire = 1 count` for fire scenarios

### Issue: All trees die in fire scenarios
**Cause:** Fire mortality too high, or conditional syntax error
**Solution:** Use `:if/:elif` syntax for multi-branch conditionals (see CONTEXT.md)

### Issue: Interventions have no effect
**Cause:** Parameters too small, or invasive dynamics not working
**Solution:** Increase `seedingBoost` and `removalEffort`; check invasive cover over time

### Issue: No spatial patterns visible
**Cause:** Elevation/fire data not loaded correctly
**Solution:** Check preprocessing used band 0; verify `.jshd` files exist

## Files to Modify

| File | Purpose | When to Modify |
|------|---------|----------------|
| `configs/params.jshc` | All ecological parameters | Most parameter tuning |
| `vegetation_model.josh` | Model logic | Structural changes, new dynamics |
| `scenario.jshc` | Current scenario settings | Switching scenarios |
| `data/*.tif` | Spatial input data | Changing fire/elevation patterns |

## Validation Checklist

Before finalizing the model, verify:

- [ ] Baseline shows stable tree population (no fire impact)
- [ ] Fire scenarios show significant tree mortality at step 0
- [ ] High elevation areas have lower invasive cover than low elevation
- [ ] High elevation shows better tree recovery than low elevation
- [ ] Seeding intervention increases tree count
- [ ] Removal intervention reduces invasive cover
- [ ] Combined intervention performs best
- [ ] Spatial patterns are visible in figures
- [ ] Time series show expected trajectories

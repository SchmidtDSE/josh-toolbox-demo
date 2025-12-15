# Stability Sweep: Optimizing for Ecological Realism

## Problem Statement

The previous parameter sweep optimized for **maximum differentiation** between elevation zones after fire, which led to:
- Complete ecosystem collapse at low elevation (99%+ invasive cover)
- Near-zero invasive presence at high elevation
- No realistic coexistence dynamics

This is ecologically unrealistic. Real systems show:
- **Coexistence** at equilibrium (natives and invasives both present)
- **Gradient responses** to disturbance (not binary flip)
- **Recovery potential** even after significant disturbance

## Goals for Ecological Realism

### Baseline (No Fire) Equilibrium
After 100+ years without disturbance, the system should reach a stable equilibrium:

| Elevation Zone | Native Trees | Invasive Cover | Description |
|----------------|--------------|----------------|-------------|
| High (>60%) | 8-10 per patch | 5-15% | Natives dominant, invasives suppressed |
| Medium (30-60%) | 6-9 per patch | 15-30% | Coexistence, natives have edge |
| Low (<30%) | 4-7 per patch | 25-45% | Coexistence, invasives competitive |

**Key insight**: Even at low elevation, natives should persist at equilibrium. The system is not "invasive-dominated" without disturbance.

### Post-Fire Response (Fire Only)
After fire, the system should show:

| Elevation Zone | Invasive Cover (Year 50) | Trees (Year 50) | Recovery Trajectory |
|----------------|--------------------------|-----------------|---------------------|
| High | 10-25% | 70-90% of baseline | Recovering toward baseline |
| Medium | 25-50% | 50-70% of baseline | Slow recovery |
| Low | 40-70% | 30-60% of baseline | Challenged but not collapsed |

**Key insight**: Low elevation is *challenged* by fire but not *lost*. Trees persist, invasives gain ground but don't achieve total dominance.

### Intervention Effectiveness
With interventions, low elevation should show meaningful improvement:
- Seeding: +10-20% more trees than fire_only
- Removal: -15-25% invasive cover vs fire_only
- Combined: Approaches medium-elevation recovery trajectory

---

## Sweep Design

### Simulation Parameters

```yaml
totalSteps: 200        # Extended run for equilibrium assessment
coldStartIgnore: 100   # Ignore first 100 years
evaluationWindow: 100  # Evaluate years 100-200
```

### Scenarios to Run

1. **Baseline only** for stability metrics
   - No fire, no intervention
   - Evaluate equilibrium state and stability

2. **Fire scenarios** for differentiation metrics (optional, secondary)
   - Run separately after finding stable baseline parameters

### Parameters to Sweep

Focus on parameters that affect **coexistence dynamics**:

| Parameter | Range | Rationale |
|-----------|-------|-----------|
| `treeSuppression` | 0.2, 0.3, 0.4, 0.5 | How effectively trees suppress invasives |
| `invasiveBaseGrowthRate` | 5%, 8%, 12% | How fast invasives spread |
| `nativeEstablishmentThreshold` | 40%, 50%, 60% | Invasive cover allowing native establishment |
| `seedlingBaseMortality` | 30%, 40%, 50% | Baseline seedling survival |

**Fixed parameters** (elevation effects - tune after baseline is stable):
- `elevationInvasiveGrowthReduction`: 25% (moderate)
- `elevationInitialInvasiveReduction`: 30% (moderate)
- `seedlingElevationReduction`: 25% (moderate)

### Total Configurations

4 × 3 × 3 × 3 = **108 configurations**

With 200 steps and ~50 seconds per run, expect ~90 minutes total.

---

## Scoring Criteria

### Primary: Baseline Stability (Years 100-200)

Evaluate the **baseline scenario only** for ecological realism.

#### Stability Metrics

1. **Population Stability** (25 points)
   - Coefficient of variation (CV) of total trees over years 100-200
   - Target: CV < 10%
   - Score: 25 if CV < 5%, 15 if CV < 10%, 0 otherwise

2. **Equilibrium Tree Density** (25 points)
   - Mean trees per patch over years 100-200
   - Target: 5-9 trees/patch (not at ceiling, not collapsed)
   - Score: 25 if 6-8, 15 if 5-9, 0 otherwise

3. **Elevation Gradient in Trees** (25 points)
   - Ratio of high_elev trees to low_elev trees
   - Target: 1.2-2.0x (moderate gradient, not extreme)
   - Score: 25 if 1.3-1.8x, 15 if 1.2-2.0x, 0 otherwise

4. **Invasive Coexistence** (25 points)
   - Mean invasive cover at low elevation
   - Target: 20-40% (present but not dominant)
   - Score: 25 if 25-35%, 15 if 20-40%, 0 otherwise

#### Scoring Function

```python
def score_baseline_stability(results_100_200):
    """Score a configuration based on baseline ecological realism."""

    # 1. Population stability (CV of total trees)
    tree_totals = results_100_200.groupby('step')['numAlive'].sum()
    cv = tree_totals.std() / tree_totals.mean()
    stability_score = 25 if cv < 0.05 else (15 if cv < 0.10 else 0)

    # 2. Equilibrium density
    final_50 = results_100_200[results_100_200['step'] >= 150]
    mean_trees_per_patch = final_50['numAlive'].mean()
    density_score = 25 if 6 <= mean_trees_per_patch <= 8 else (
        15 if 5 <= mean_trees_per_patch <= 9 else 0)

    # 3. Elevation gradient
    low_elev = final_50[final_50['elevation'] < 30]['numAlive'].mean()
    high_elev = final_50[final_50['elevation'] >= 60]['numAlive'].mean()
    ratio = high_elev / max(low_elev, 0.1)
    gradient_score = 25 if 1.3 <= ratio <= 1.8 else (
        15 if 1.2 <= ratio <= 2.0 else 0)

    # 4. Invasive coexistence at low elevation
    low_invasive = final_50[final_50['elevation'] < 30]['invasiveCover'].mean() * 100
    coexist_score = 25 if 25 <= low_invasive <= 35 else (
        15 if 20 <= low_invasive <= 40 else 0)

    return {
        'stability_score': stability_score,
        'density_score': density_score,
        'gradient_score': gradient_score,
        'coexist_score': coexist_score,
        'total_score': stability_score + density_score + gradient_score + coexist_score,
        'cv': cv,
        'mean_trees': mean_trees_per_patch,
        'elev_ratio': ratio,
        'low_invasive': low_invasive
    }
```

### Secondary: Fire Response (After Baseline Tuned)

Only evaluate fire scenarios **after** finding stable baseline parameters.

| Metric | Target | Points |
|--------|--------|--------|
| Low elev invasive increase | +20-40% vs baseline | 25 |
| Low elev trees remaining | 40-70% of baseline | 25 |
| High elev recovery | >80% of baseline trees | 25 |
| Differentiation | Low invasive 1.5-3x high invasive | 25 |

---

## Implementation

### Step 1: Generate Sweep Configurations

Create `configs/sweep/stability_sweep_definitions.csv`:

```csv
path,treeSuppression,treeSuppression_unit,invasiveBaseGrowthRate,invasiveBaseGrowthRate_unit,nativeEstablishmentThreshold,nativeEstablishmentThreshold_unit,seedlingBaseMortality,seedlingBaseMortality_unit
stability/supp_20/growth_5/thresh_40/mort_30,0.2,,5,percent,40,percent,30,percent
stability/supp_20/growth_5/thresh_40/mort_40,0.2,,5,percent,40,percent,40,percent
...
```

### Step 2: Update params.jshc for 200-Step Run

```jshc
totalSteps = 200 count
```

### Step 3: Run Baseline-Only Sweep

```bash
# Only run baseline scenario for each config
for config in configs/sweep/stability_*/params.jshc; do
    # Merge configs
    # Run with scenario.jshc=configs/base/baseline.jshc
    # Save results
done
```

### Step 4: Analyze Results (Years 100-200 Only)

```python
# Load results
df = pd.read_csv(results_file)

# Filter to evaluation window
eval_window = df[(df['step'] >= 100) & (df['step'] <= 200)]

# Score configuration
scores = score_baseline_stability(eval_window)
```

### Step 5: Select Best Configuration

Rank by total_score, then by:
1. Closest to target coexistence (25-35% invasive at low elev)
2. Most stable (lowest CV)
3. Best gradient (closest to 1.5x ratio)

---

## Expected Outcomes

### Best Configuration Profile

A well-tuned configuration should show:

```
BASELINE STABILITY RESULTS (Years 100-200)
==========================================
Total Score: 85-100/100

Population Stability:
  CV: 3-5%
  Interpretation: Stable equilibrium, normal fluctuation

Tree Density:
  Mean: 6-7 trees/patch
  Not at carrying capacity (10), not collapsing

Elevation Gradient:
  High elev: 7-8 trees/patch
  Low elev: 5-6 trees/patch
  Ratio: 1.4-1.6x

Invasive Coexistence:
  High elev: 10-15% cover
  Low elev: 28-35% cover
  Gradient: 2-3x more at low elev
```

### Why This Matters

With these baseline parameters:
1. **Baseline is a credible counterfactual** - stable, realistic coexistence
2. **Fire creates a meaningful challenge** - invasives gain ground but don't win completely
3. **Interventions can help** - there's room for recovery, not just preventing total loss
4. **Elevation gradient is visible but not extreme** - management priorities are clear but not binary

---

## Files to Create/Modify

1. `configs/sweep/stability_sweep_definitions.csv` - Parameter combinations
2. `configs/base/params.jshc` - Update `totalSteps = 200`
3. `configs/sweep/run_stability_sweep.sh` - Baseline-only sweep script
4. `analysis/score_stability.py` - Scoring function implementation
5. `tuning_workflow.ipynb` - Add stability sweep analysis section

---

## Next Steps

1. [ ] Create stability sweep definitions CSV
2. [ ] Update params.jshc for 200 steps
3. [ ] Implement scoring function
4. [ ] Run sweep (~90 minutes)
5. [ ] Analyze results and select best configuration
6. [ ] Validate with fire scenarios
7. [ ] Update demo workflow with stable parameters

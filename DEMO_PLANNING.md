# Post-Fire Vegetation Recovery Demonstration: Detailed Work Plan

## Overview

This document specifies a complete end-to-end demonstration of the post-fire decision support toolbox workflow using the Josh simulation engine. The demonstration creates a toy ecological system with native trees and invasive grasses, applies a synthetic fire disturbance, and compares recovery outcomes under different management interventions.

---

## 1. Ecological System Design

### 1.1 Native Tree Species (`NativeTree`)

Individual agents with a three-stage life cycle managed via Josh state machine.

#### Life Stage Parameters

| Stage | Age Range | Annual Mortality | Notes |
|-------|-----------|------------------|-------|
| Seedling | 0-2 years | 40% | High herbivory pressure; blocked by invasive cover |
| Juvenile | 3-9 years | 15% | Established but not reproductive |
| Adult | 10+ years | 5% | Reproductive; produces seedlings |

#### Reproduction

- Adults produce seedlings each year: `sample uniform from 0 count to 2 count`
- Seedling production only occurs if patch is below maximum tree density (10 trees)
- New seedlings are added at the `end` event to begin their first step next year

#### Establishment Constraint

- Seedlings cannot establish (die immediately) if `invasiveCover > 50%`
- This creates the competitive exclusion dynamic where invasives prevent native recovery

#### Fire Response

Fire mortality depends on severity level and life stage:

| Severity Range | Seedling Mortality | Juvenile Mortality | Adult Mortality |
|----------------|--------------------|--------------------|-----------------|
| 0.0 - 0.3 (low) | 20% | 10% | 5% |
| 0.3 - 0.7 (moderate) | 80% | 50% | 20% |
| 0.7 - 1.0 (high) | 100% | 90% | 60% |

### 1.2 Invasive Grass (`invasiveCover`)

Patch-level attribute representing percentage cover (0-100%).

#### Growth Dynamics

- Base growth rate: +3% per year (logistic, slowing as cover increases)
- Growth formula: `prior.invasiveCover + growthRate * (1 - prior.invasiveCover / 100%)`
- Maximum cover: 100%

#### Post-Fire Dynamics

- Fire reduces invasive cover based on severity:
  - High severity (>0.7): Cover reduced to 10%
  - Moderate severity (0.3-0.7): Cover reduced to 30%
  - Low severity (<0.3): Cover reduced to 50%
- **Critical dynamic**: Invasives recover faster than trees in disturbed areas
- Post-fire growth rate bonus: +5% additional growth for 5 years after fire

#### Competition Effect

- When `invasiveCover > 50%`: Seedling establishment blocked
- When `invasiveCover > 30%`: Seedling mortality increased by 20%

### 1.3 System Equilibrium Expectations

After 1000-year cold start:
- Tree population should stabilize at near-maximum density in most patches
- Invasive cover should be low (~5-15%) due to tree competition/shading
- Some natural variation due to stochastic mortality and reproduction

---

## 2. Spatial Configuration

### 2.1 Grid Specification

| Parameter | Value |
|-----------|-------|
| Grid dimensions | 30 × 30 patches |
| Patch size | 10m × 10m |
| Total extent | 300m × 300m |
| Total patches | 900 |
| Coordinate system | Local metric (meters) |

### 2.2 Grid Bounds

Using a simple local coordinate system in meters for intuitive visualization:

```
Origin: (0m, 0m)
Extent: (300m, 300m)
```

The grid uses x/y coordinates in meters, making it easy to understand spatial relationships and patch sizes at a glance.

### 2.3 Maximum Density

- Maximum trees per patch: 10
- This represents ~1000 trees/hectare at full density
- Enforced during seedling creation

---

## 3. Temporal Configuration

### 3.1 Cold-Start Phase

| Parameter | Value |
|-----------|-------|
| Duration | 1000 years |
| Purpose | Establish quasi-stable equilibrium |
| Fire | None |
| Interventions | None |
| Replicates | 1 (with fixed seed for reproducibility) |

The final state of the cold-start becomes the initial condition for all scenario runs.

### 3.2 Scenario Phase

| Parameter | Value |
|-----------|-------|
| Duration | 50 years post-fire |
| Fire timing | Year 0 (applied as initial condition) |
| Interventions | Applied at Year 0-5 depending on scenario |
| Replicates | 100 per scenario |
| Random seed | Varied across replicates |

---

## 4. External Data Specification

### 4.1 Fire Severity Raster (`fire_severity.tif`)

#### Spatial Pattern

Noisy 2D Gaussian centered on grid, simulating a single ignition point fire with realistic irregularity:

```python
# Pseudocode
center_x, center_y = 15, 15  # Grid center (0-indexed for 30x30)
sigma = 7  # Standard deviation in grid cells (larger for 30x30)
noise_scale = 0.25  # Adds realistic variability

# Base Gaussian
severity = 0.95 * exp(-distance_sq / (2 * sigma**2))

# Add spatially-correlated noise and wind effect
# Noise is stronger at fire edges (moderate severity zones)
# Wind creates directional bias
```

#### Expected Pattern

- Peak severity: ~0.95 at center (with some noise)
- Moderate severity (0.3-0.7): Irregular ring from ~5-12 cells from center
- Low severity (<0.3): Outer edges with noisy boundary
- Unburned (0): Corners of grid
- Irregular edges: Spatially-correlated noise creates realistic fire perimeter
- Wind effect: Slight directional elongation of the burn pattern

#### File Specifications

| Property | Value |
|----------|-------|
| Format | GeoTIFF |
| Data type | Float32 |
| NoData value | -9999 |
| CRS | Local metric (transverse Mercator, meters) |
| Dimensions | 30 × 30 pixels |
| Resolution | 10m × 10m |

### 4.2 Seeding Intensity Raster (`seeding_intensity.tif`)

#### Spatial Pattern

Ring around high-severity core, targeting moderate-severity areas where:
- Fire killed many trees but some seed sources remain nearby
- Invasive pressure is elevated but not overwhelming

```python
# Pseudocode - target moderate severity ring
seeding = np.zeros((30, 30))
for i in range(30):
    for j in range(30):
        if 0.3 < fire_severity[i, j] < 0.7:
            seeding[i, j] = 5  # Plant 5 seedlings per patch
```

#### File Specifications

| Property | Value |
|----------|-------|
| Format | GeoTIFF |
| Data type | Int16 |
| Values | 0-10 (seedlings to plant) |
| CRS | Local metric (meters) |
| Dimensions | 30 × 30 pixels |

### 4.3 Invasive Removal Raster (`removal_intensity.tif`)

#### Spatial Pattern

Target high-severity areas where invasive takeover is most likely:

```python
# Pseudocode - target high severity areas
removal = np.zeros((30, 30))
for i in range(30):
    for j in range(30):
        if fire_severity[i, j] > 0.5:
            removal[i, j] = 1  # Flag for removal treatment
```

#### Treatment Effect

Where `removal == 1`:
- Invasive cover set to 0% at Year 0
- Invasive growth rate reduced by 50% for 10 years (simulating ongoing maintenance)

#### File Specifications

| Property | Value |
|----------|-------|
| Format | GeoTIFF |
| Data type | Int16 |
| Values | 0 or 1 (binary treatment flag) |
| CRS | Local metric (meters) |
| Dimensions | 30 × 30 pixels |

---

## 5. Scenario Definitions

### 5.1 Scenario Matrix

| Scenario ID | Name | Fire | Seeding | Removal | Purpose |
|-------------|------|------|---------|---------|---------|
| 0 | `coldstart` | No | No | No | Establish equilibrium |
| 1 | `baseline` | No | No | No | Control (no disturbance) |
| 2 | `fire_only` | Yes | No | No | Fire impact without intervention |
| 3 | `fire_seeding` | Yes | Yes | No | Test seeding effectiveness |
| 4 | `fire_removal` | Yes | No | Yes | Test invasive removal effectiveness |
| 5 | `fire_both` | Yes | Yes | Yes | Combined intervention |

### 5.2 Configuration Variables

Each scenario controlled via `.jshc` configuration file:

```
# Example: fire_both.jshc
fireOccurred = 1 bool
seedingIntervention = 1 bool
invasiveRemoval = 1 bool
```

The Josh model reads these via `config scenarioName.variableName` expressions.

---

## 6. Josh Model Architecture

### 6.1 File: `vegetation_model.josh`

#### Unit Definitions

```josh
start unit year
  alias years
  alias yr
  alias yrs
end unit

start unit percent
  alias pct
end unit
```

#### Simulation Stanza

```josh
start simulation Main
  # Spatial configuration: 30x30 grid of 10m patches (300m x 300m)
  grid.size = 10 m
  grid.low = 0 m latitude, 0 m longitude
  grid.high = 300 m latitude, 300 m longitude
  grid.patch = "Default"

  # Temporal configuration (set via config for cold-start vs scenario)
  steps.low = 0 count
  steps.high = config settings.numSteps else 50 count

  # Ecological constraints
  constraints.maxTreesPerPatch = 10 count
  constraints.invasiveEstablishmentThreshold = 50 percent
  constraints.invasiveMortalityThreshold = 30 percent

  # Random seed (for reproducibility in cold-start)
  # randSeed = config settings.randomSeed else 12345

  # Export configuration
  exportFiles.patch = config settings.outputPath else "file://results/output"
end simulation
```

#### Patch Stanza

```josh
start patch Default
  # === INITIALIZATION ===

  # Initial tree population (for cold-start; scenarios load from equilibrium)
  initialTreeCount.init = config settings.initialTrees else 5 count
  NativeTree.init = create initialTreeCount of NativeTree

  # Initial invasive cover
  invasiveCover.init = config settings.initialInvasive else 10 percent

  # === FIRE EFFECTS (Year 0 only) ===

  # Read fire severity from external data (0 if no fire)
  fireSeverity.init = {
    const fireOccurred = config scenario.fireOccurred else false
    return (external fireSeverity) if fireOccurred else 0
  }

  # Apply fire mortality to trees at start of step 0
  # (Handled within NativeTree organism via fireSeverity access)

  # Apply fire effects to invasive cover
  invasiveCover.start:if(meta.stepCount == 0 and fireSeverity > 0) = {
    const severity = here.fireSeverity
    const postFireCover = 10 percent if severity > 0.7
      else (30 percent if severity > 0.3 else 50 percent)
    return postFireCover
  }

  # === MANAGEMENT INTERVENTIONS ===

  # Seeding intervention (Year 0)
  seedlingAddition.init = {
    const doSeeding = config scenario.seedingIntervention else false
    const intensity = external seedingIntensity
    return intensity if doSeeding else 0 count
  }
  NativeTree.init:if(seedlingAddition > 0) = {
    const base = create initialTreeCount of NativeTree
    const added = create seedlingAddition of NativeTree
    return base | added
  }

  # Invasive removal intervention
  removalActive.init = {
    const doRemoval = config scenario.invasiveRemoval else false
    const inTreatmentZone = (external removalIntensity) > 0
    return doRemoval and inTreatmentZone
  }
  invasiveCover.init:if(removalActive) = 0 percent

  # Track removal status for ongoing growth suppression
  yearsOfRemoval.init = 10 count if removalActive else 0 count
  yearsOfRemoval.step = limit (prior.yearsOfRemoval - 1 count) to [0 count,]

  # === INVASIVE DYNAMICS ===

  # Base growth rate (reduced if removal treatment active)
  invasiveGrowthRate.step = {
    const baseRate = 3 percent
    const postFireBonus = 5 percent if (meta.stepCount < 5 and fireSeverity > 0) else 0 percent
    const removalPenalty = 0.5 if yearsOfRemoval > 0 count else 1
    return (baseRate + postFireBonus) * removalPenalty
  }

  # Logistic growth with tree suppression
  treeSuppression.step = {
    const treeCount = count(NativeTree)
    const maxTrees = meta.constraints.maxTreesPerPatch
    return 1 - (treeCount / maxTrees) * 0.8  # Trees suppress invasive growth
  }

  invasiveCover.step = {
    const growth = invasiveGrowthRate * treeSuppression * (1 - prior.invasiveCover / 100 percent)
    const newCover = prior.invasiveCover + growth
    return limit newCover to [0 percent, 100 percent]
  }

  # === TREE POPULATION MANAGEMENT ===

  # Remove dead trees at start of step
  NativeTree.start = prior.NativeTree[prior.NativeTree.alive == true]

  # Add new seedlings from reproduction at end of step
  reproductionCount.end = {
    const adults = count(NativeTree[NativeTree.state == "adult"])
    const perAdult = sample uniform from 0 count to 2 count
    const potential = adults * perAdult
    const currentCount = count(NativeTree)
    const maxNew = meta.constraints.maxTreesPerPatch - currentCount
    return limit potential to [0 count, maxNew]
  }

  canEstablish.end = invasiveCover < meta.constraints.invasiveEstablishmentThreshold

  NativeTree.end = {
    const current = prior.NativeTree
    const newSeedlings = create reproductionCount of NativeTree if canEstablish else create 0 count of NativeTree
    return current | newSeedlings
  }

  # === EXPORTS ===

  export.seedlingCount.step = count(NativeTree[NativeTree.state == "seedling"])
  export.juvenileCount.step = count(NativeTree[NativeTree.state == "juvenile"])
  export.adultCount.step = count(NativeTree[NativeTree.state == "adult"])
  export.totalTrees.step = count(NativeTree)
  export.invasiveCover.step = invasiveCover
  export.fireSeverity.step = fireSeverity

end patch
```

#### Organism Stanza

```josh
start organism NativeTree

  # === INITIALIZATION ===

  alive.init = true
  age.init = 0 years

  # Determine initial state based on age (for loaded equilibrium)
  state.init = {
    if (current.age >= 10 years) {
      return "adult"
    } elif (current.age >= 3 years) {
      return "juvenile"
    } else {
      return "seedling"
    }
  }

  # === FIRE MORTALITY (Year 0) ===

  fireDeathRoll.init = sample uniform from 0 percent to 100 percent

  alive.init:if(here.fireSeverity > 0) = {
    const severity = here.fireSeverity
    const myState = current.state

    # Determine mortality threshold based on severity and state
    const threshold = {
      if (severity > 0.7) {
        return 100 percent if myState == "seedling"
          else (90 percent if myState == "juvenile" else 60 percent)
      } elif (severity > 0.3) {
        return 80 percent if myState == "seedling"
          else (50 percent if myState == "juvenile" else 20 percent)
      } else {
        return 20 percent if myState == "seedling"
          else (10 percent if myState == "juvenile" else 5 percent)
      }
    }

    return fireDeathRoll > threshold
  }

  # === AGE PROGRESSION ===

  age.step = prior.age + 1 year

  # === SEEDLING STATE ===

  start state "seedling"

    # Base mortality plus invasive pressure
    baseMortality.step = 40 percent
    invasivePressure.step = {
      const cover = here.invasiveCover
      const threshold = meta.constraints.invasiveMortalityThreshold
      return 20 percent if cover > threshold else 0 percent
    }
    totalMortality.step = baseMortality + invasivePressure

    deathRoll.step = sample uniform from 0 percent to 100 percent
    alive.step = deathRoll > totalMortality

    # Transition to juvenile at age 3
    state.step:if(current.age >= 3 years and alive) = "juvenile"

  end state

  # === JUVENILE STATE ===

  start state "juvenile"

    baseMortality.step = 15 percent
    deathRoll.step = sample uniform from 0 percent to 100 percent
    alive.step = deathRoll > baseMortality

    # Transition to adult at age 10
    state.step:if(current.age >= 10 years and alive) = "adult"

  end state

  # === ADULT STATE ===

  start state "adult"

    baseMortality.step = 5 percent
    deathRoll.step = sample uniform from 0 percent to 100 percent
    alive.step = deathRoll > baseMortality

    # Adults stay adult (no further transitions except death)

  end state

end organism
```

### 6.2 Configuration Files

#### `configs/coldstart.jshc`
```
# Cold-start equilibration run
settings.numSteps = 1000 count
settings.initialTrees = 5 count
settings.initialInvasive = 10 percent
settings.outputPath = "file://results/coldstart"

scenario.fireOccurred = false
scenario.seedingIntervention = false
scenario.invasiveRemoval = false
```

#### `configs/baseline.jshc`
```
# Baseline: no fire, no intervention
settings.numSteps = 50 count
settings.outputPath = "file://results/baseline"

scenario.fireOccurred = false
scenario.seedingIntervention = false
scenario.invasiveRemoval = false
```

#### `configs/fire_only.jshc`
```
# Fire impact without intervention
settings.numSteps = 50 count
settings.outputPath = "file://results/fire_only"

scenario.fireOccurred = true
scenario.seedingIntervention = false
scenario.invasiveRemoval = false
```

#### `configs/fire_seeding.jshc`
```
# Fire with seeding intervention
settings.numSteps = 50 count
settings.outputPath = "file://results/fire_seeding"

scenario.fireOccurred = true
scenario.seedingIntervention = true
scenario.invasiveRemoval = false
```

#### `configs/fire_removal.jshc`
```
# Fire with invasive removal
settings.numSteps = 50 count
settings.outputPath = "file://results/fire_removal"

scenario.fireOccurred = false
scenario.seedingIntervention = false
scenario.invasiveRemoval = true
```

#### `configs/fire_both.jshc`
```
# Fire with both interventions
settings.numSteps = 50 count
settings.outputPath = "file://results/fire_both"

scenario.fireOccurred = true
scenario.seedingIntervention = true
scenario.invasiveRemoval = true
```

---

## 7. Data Preprocessing Pipeline

### 7.1 GeoTIFF Generation (Python)

```python
import numpy as np
import rasterio
from rasterio.transform import from_bounds
from rasterio.crs import CRS

# Grid parameters (30x30 in meters)
n_rows, n_cols = 30, 30
x_low, x_high = 0, 300
y_low, y_high = 0, 300

# Create transform (maps pixel coordinates to geographic coordinates)
transform = from_bounds(x_low, y_low, x_high, y_high, n_cols, n_rows)

# Common metadata (using local metric CRS)
profile = {
    'driver': 'GTiff',
    'dtype': 'float32',
    'width': n_cols,
    'height': n_rows,
    'count': 1,
    'crs': CRS.from_proj4('+proj=tmerc +lat_0=0 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs'),
    'transform': transform,
    'nodata': -9999
}
```

### 7.2 Josh Preprocessing (Bash)

```bash
# Preprocess fire severity (using x/y coordinates for metric grid)
java -jar jar/joshsim-fat-dev.jar preprocess \
    vegetation_model.josh Main \
    data/fire_severity.tif fireSeverity "ratio" \
    preprocessed/fire_severity.jshd \
    --x-coord x --y-coord y

# Preprocess seeding intensity
java -jar jar/joshsim-fat-dev.jar preprocess \
    vegetation_model.josh Main \
    data/seeding_intensity.tif seedingIntensity "count" \
    preprocessed/seeding_intensity.jshd \
    --x-coord x --y-coord y

# Preprocess removal zones
java -jar jar/joshsim-fat-dev.jar preprocess \
    vegetation_model.josh Main \
    data/removal_intensity.tif removalIntensity "count" \
    preprocessed/removal_intensity.jshd \
    --x-coord x --y-coord y
```

---

## 8. Simulation Execution Pipeline

### 8.1 Cold-Start Run

```bash
# Single replicate, 1000 years
java -jar jar/joshsim-fat-dev.jar run \
    vegetation_model.josh Main \
    --replicates 1 \
    -o results/coldstart/
```

### 8.2 Scenario Runs

```bash
# For each scenario config file:
for scenario in baseline fire_only fire_seeding fire_removal fire_both; do
    java -jar jar/joshsim-fat-dev.jar run \
        vegetation_model.josh Main \
        --replicates 100 \
        -o results/${scenario}/
done
```

Note: Configuration files are loaded automatically from working directory based on naming convention, or can be specified explicitly.

---

## 9. Output Specification

### 9.1 Expected CSV Structure

Each scenario produces patch-level CSV exports with columns:

| Column | Type | Description |
|--------|------|-------------|
| `replicate` | int | Replicate number (1-100) |
| `step` | int | Time step (0-50) |
| `x` | int | Patch x-coordinate (0-19) |
| `y` | int | Patch y-coordinate (0-19) |
| `seedlingCount` | int | Number of seedling-stage trees |
| `juvenileCount` | int | Number of juvenile-stage trees |
| `adultCount` | int | Number of adult-stage trees |
| `totalTrees` | int | Total trees in patch |
| `invasiveCover` | float | Invasive grass cover (0-100) |
| `fireSeverity` | float | Fire severity at this patch (0-1) |

### 9.2 File Organization

```
results/
├── coldstart/
│   └── patches.csv
├── baseline/
│   └── patches.csv
├── fire_only/
│   └── patches.csv
├── fire_seeding/
│   └── patches.csv
├── fire_removal/
│   └── patches.csv
└── fire_both/
    └── patches.csv
```

---

## 10. Analysis and Visualization

### 10.1 R Data Loading

```r
library(tidyverse)

# Load all scenarios
scenarios <- c("baseline", "fire_only", "fire_seeding", "fire_removal", "fire_both")

data <- map_dfr(scenarios, function(s) {
  read_csv(paste0("results/", s, "/patches.csv")) %>%
    mutate(scenario = s)
})

# Aggregate across space for time series
time_series <- data %>%
  group_by(scenario, replicate, step) %>%
  summarise(
    totalSeedlings = sum(seedlingCount),
    totalJuveniles = sum(juvenileCount),
    totalAdults = sum(adultCount),
    totalTrees = sum(totalTrees),
    meanInvasive = mean(invasiveCover),
    .groups = "drop"
  )
```

### 10.2 Time Series Visualizations

```r
# Tree population over time
ggplot(time_series, aes(x = step, y = totalTrees, color = scenario)) +
  stat_summary(fun = mean, geom = "line", size = 1) +
  stat_summary(fun.data = mean_se, geom = "ribbon", alpha = 0.2, color = NA) +
  labs(
    title = "Total Tree Population Over Time",
    subtitle = "Mean ± SE across 100 replicates",
    x = "Years Post-Fire",
    y = "Total Trees (all patches)",
    color = "Scenario"
  ) +
  theme_minimal()

# Invasive cover over time
ggplot(time_series, aes(x = step, y = meanInvasive, color = scenario)) +
  stat_summary(fun = mean, geom = "line", size = 1) +
  stat_summary(fun.data = mean_se, geom = "ribbon", alpha = 0.2, color = NA) +
  labs(
    title = "Mean Invasive Cover Over Time",
    x = "Years Post-Fire",
    y = "Invasive Cover (%)",
    color = "Scenario"
  ) +
  theme_minimal()
```

### 10.3 Spatial Visualizations

```r
# Final state maps (Year 50, single replicate for clarity)
final_state <- data %>%
  filter(step == 50, replicate == 1)

ggplot(final_state, aes(x = x, y = y, fill = totalTrees)) +
  geom_tile() +
  facet_wrap(~scenario, ncol = 3) +
  scale_fill_viridis_c(option = "D", limits = c(0, 10)) +
  coord_fixed() +
  labs(
    title = "Tree Density at Year 50",
    fill = "Trees/patch"
  ) +
  theme_minimal()

# Invasive cover maps
ggplot(final_state, aes(x = x, y = y, fill = invasiveCover)) +
  geom_tile() +
  facet_wrap(~scenario, ncol = 3) +
  scale_fill_gradient(low = "white", high = "darkgreen", limits = c(0, 100)) +
  coord_fixed() +
  labs(
    title = "Invasive Cover at Year 50",
    fill = "Cover (%)"
  ) +
  theme_minimal()
```

---

## 11. Expected Results

### 11.1 Qualitative Predictions

| Scenario | Tree Trajectory | Invasive Trajectory |
|----------|-----------------|---------------------|
| Baseline | Stable at equilibrium | Stable low |
| Fire Only | Decline, especially in center; slow/no recovery | Rapid increase in burned areas |
| Fire + Seeding | Better recovery than fire-only | Still elevated |
| Fire + Removal | Moderate recovery | Suppressed in treatment zones |
| Fire + Both | Best recovery | Lowest overall |

### 11.2 Key Metrics to Compare

1. **Year 50 total tree population** (% of baseline)
2. **Year 50 mean invasive cover**
3. **Time to recovery** (if applicable)
4. **Spatial pattern of recovery** (center vs edge of burn)

---

## 12. File Manifest

```
demo_workflow/
├── DEMO_PLANNING.md              # This document
├── vegetation_model.josh         # Core Josh simulation model
├── configs/
│   ├── coldstart.jshc
│   ├── baseline.jshc
│   ├── fire_only.jshc
│   ├── fire_seeding.jshc
│   ├── fire_removal.jshc
│   └── fire_both.jshc
├── data/                         # Generated GeoTIFFs
│   ├── fire_severity.tif
│   ├── seeding_intensity.tif
│   └── removal_intensity.tif
├── preprocessed/                 # Josh .jshd files
│   ├── fire_severity.jshd
│   ├── seeding_intensity.jshd
│   └── removal_intensity.jshd
├── results/                      # Simulation outputs
│   ├── coldstart/
│   ├── baseline/
│   ├── fire_only/
│   ├── fire_seeding/
│   ├── fire_removal/
│   └── fire_both/
├── demo_workflow.ipynb           # Main Jupyter notebook
└── analysis/
    └── visualizations.R          # R script for ggplot2
```

---

## 13. Implementation Notes

### 13.1 Known Simplifications

This toy model makes several simplifications for demonstration purposes:

1. **No spatial spread**: Trees don't disperse seeds to neighboring patches
2. **Uniform fire response**: All trees of same stage respond identically
3. **Simple competition**: Binary threshold for invasive effects
4. **No climate variability**: Constant environmental conditions
5. **Instantaneous interventions**: Seeding/removal applied at single time point

### 13.2 Potential Extensions

For a more realistic model, consider:

1. Spatial seed dispersal using `within ... radial` queries
2. Climate-driven variability in mortality and growth
3. Multi-year intervention programs
4. Multiple native species with different traits
5. Herbivory as explicit agents rather than implicit mortality

### 13.3 Debugging Tips

- Start with small grid (5×5) and few steps (10) to verify logic
- Use `--verbose` flag to see detailed execution
- Check exports at step 0 to verify initialization
- Compare single replicate across scenarios before running 100

---

## 14. Alignment with Toolbox Philosophy

This demonstration embodies the toolbox design principles:

| Principle | Implementation |
|-----------|----------------|
| **Partner-driven** | Addresses real questions: fire impact, intervention effectiveness |
| **Transparency** | All parameters explicit in Josh code; inspectable logic |
| **Process-based** | Life stages, mortality rates, competition—not black-box ML |
| **Uncertainty** | 100 replicates to characterize stochastic variation |
| **Open tools** | Josh is open source; notebook fully reproducible |

---

*Document version: 1.0*
*Created for Josh Simulation Engine demonstration workflow*

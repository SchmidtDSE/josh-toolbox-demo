#!/usr/bin/env python3
"""
Run multiple scenarios for post-fire vegetation recovery comparison.

Reads parameters from configs/params.jshc and generates Josh models.
Scenario-specific configs define: hasFire, seedingBoost, removalEffort

Scenarios:
1. baseline - No fire, no intervention (counterfactual)
2. fire_only - Fire, no intervention
3. fire_seeding - Fire + seeding intervention
4. fire_removal - Fire + invasive removal
5. fire_both - Fire + both interventions
"""

import subprocess
import os
import csv
import shutil
import re

# Paths
PARAMS_CONFIG = "/workspace/configs/params.jshc"
FIRE_DATA = "/workspace/preprocessed/fire_severity.jshd"
RESULTS_DIR = "/workspace/results"

# Scenarios: (name, has_fire, seeding_boost, removal_effort)
SCENARIOS = [
    ("baseline",      False, 0,  0),
    ("fire_only",     True,  0,  0),
    ("fire_seeding",  True,  8,  0),
    ("fire_removal",  True,  0,  12),
    ("fire_both",     True,  8,  12),
]


def parse_jshc(filepath):
    """Parse a .jshc config file into a dictionary."""
    params = {}
    with open(filepath, 'r') as f:
        for line in f:
            line = line.split('#')[0].strip()  # Remove comments
            if '=' in line:
                key, value = line.split('=', 1)
                key = key.strip()
                value = value.strip()
                # Extract numeric value and units
                match = re.match(r'([0-9.]+)\s*(\w*)', value)
                if match:
                    num = float(match.group(1))
                    unit = match.group(2) if match.group(2) else ''
                    params[key] = (num, unit)
    return params


def generate_model(scenario_name, has_fire, seeding_boost, removal_effort, params):
    """Generate a Josh model file using parameters from config."""

    # Extract parameters
    total_steps = int(params['totalSteps'][0])
    initial_trees = int(params['initialTreesPerPatch'][0])
    max_trees = int(params['maxTreesPerPatch'][0])

    # Life stage thresholds
    seedling_to_juvenile = int(params['seedlingToJuvenileAge'][0])
    juvenile_to_adult = int(params['juvenileToAdultAge'][0])

    # Mortality rates
    seedling_mortality = int(params['seedlingBaseMortality'][0])
    juvenile_mortality = int(params['juvenileBaseMortality'][0])
    adult_mortality = int(params['adultBaseMortality'][0])
    seedling_invasive_pressure = int(params['seedlingInvasivePressure'][0])
    invasive_pressure_threshold = int(params['invasivePressureThreshold'][0])

    # Fire mortality
    fire_high_seedling = int(params['fireHighSeedling'][0])
    fire_high_juvenile = int(params['fireHighJuvenile'][0])
    fire_high_adult = int(params['fireHighAdult'][0])
    fire_med_seedling = int(params['fireMediumSeedling'][0])
    fire_med_juvenile = int(params['fireMediumJuvenile'][0])
    fire_med_adult = int(params['fireMediumAdult'][0])
    fire_low_seedling = int(params['fireLowSeedling'][0])
    fire_low_juvenile = int(params['fireLowJuvenile'][0])
    fire_low_adult = int(params['fireLowAdult'][0])

    # Fire thresholds
    high_threshold = params['highSeverityThreshold'][0]
    med_threshold = params['mediumSeverityThreshold'][0]

    # Invasive dynamics
    baseline_invasive = int(params['baselineInvasiveCover'][0])
    fire_high_invasive = int(params['fireHighInvasiveCover'][0])
    fire_med_invasive = int(params['fireMediumInvasiveCover'][0])
    fire_low_invasive = int(params['fireLowInvasiveCover'][0])
    establishment_threshold = int(params['establishmentThreshold'][0])
    base_growth = int(params['invasiveBaseGrowthRate'][0])
    post_fire_bonus = int(params['postFireGrowthBonus'][0])
    post_fire_duration = int(params['postFireBonusDuration'][0])
    tree_suppression = params['treeSuppression'][0]
    removal_duration = int(params['removalDuration'][0])

    # Initial age range
    age_min = int(params['initialAgeMin'][0])
    age_max = int(params['initialAgeMax'][0])

    # Generate fire-specific values
    if has_fire:
        fire_severity_init = "external data"
        fire_mortality = f"""{fire_high_seedling} percent if (here.fireSeverity > {high_threshold} and current.state == "Seedling") else (
    {fire_high_juvenile} percent if (here.fireSeverity > {high_threshold} and current.state == "Juvenile") else (
    {fire_high_adult} percent if (here.fireSeverity > {high_threshold} and current.state == "Adult") else (
    {fire_med_seedling} percent if (here.fireSeverity > {med_threshold} and current.state == "Seedling") else (
    {fire_med_juvenile} percent if (here.fireSeverity > {med_threshold} and current.state == "Juvenile") else (
    {fire_med_adult} percent if (here.fireSeverity > {med_threshold} and current.state == "Adult") else (
    {fire_low_seedling} percent if current.state == "Seedling" else (
    {fire_low_juvenile} percent if current.state == "Juvenile" else {fire_low_adult} percent)))))))"""
        invasive_init = f"{fire_high_invasive} percent if fireSeverity > {high_threshold} else ({fire_med_invasive} percent if fireSeverity > {med_threshold} else {fire_low_invasive} percent)"
        post_fire_bonus_expr = f"{post_fire_bonus} percent if stepCount < {post_fire_duration} count else 0 percent"
    else:
        fire_severity_init = "0"
        fire_mortality = "0 percent"
        invasive_init = f"{baseline_invasive} percent"
        post_fire_bonus_expr = "0 percent"

    model = f'''# Post-Fire Vegetation Recovery Model - {scenario_name}
# Generated from configs/params.jshc

start unit year
  alias years
end unit

start unit m
  alias meter
  alias meters
end unit

start unit count
end unit

start unit percent
  alias pct
end unit

start simulation Main

  grid.size = 10 m
  grid.low = 0.003 degrees latitude, 0 degrees longitude
  grid.high = 0 degrees latitude, 0.003 degrees longitude

  steps.low = 0 count
  steps.high = {total_steps} count

  exportFiles.patch = "file:///workspace/results/{scenario_name}_{{replicate}}.csv"

end simulation

start patch Default

  seedingBoost.init = {seeding_boost} count
  removalEffort.init = {removal_effort} percent

  fireSeverity.init = {fire_severity_init}

  NativeTree.init = create {initial_trees} count of NativeTree
  NativeTree.start = prior.NativeTree[prior.NativeTree.alive == true]

  numAdults.step = count(NativeTree[NativeTree.state == "Adult"])
  numTrees.step = count(NativeTree)
  roomForSeedlings.step = {max_trees} count - numTrees
  hasRoom.step = roomForSeedlings > 0 count
  canEstablish.step = invasiveCover < {establishment_threshold} percent

  potentialSeedlings.step = numAdults if (canEstablish and hasRoom) else 0 count
  limitedSeedlings.step = potentialSeedlings if potentialSeedlings < roomForSeedlings else roomForSeedlings
  actualNewSeedlings.step = limitedSeedlings if limitedSeedlings > 0 count else 0 count

  NativeTree.end = prior.NativeTree | create actualNewSeedlings of NativeTree

  invasiveCover.init = {invasive_init}

  stepCount.init = 0 count
  stepCount.step = prior.stepCount + 1 count

  postFireBonus.step = {post_fire_bonus_expr}
  activeRemoval.step = removalEffort if stepCount < {removal_duration} count else 0 percent

  treeSuppression.step = {tree_suppression} * (numTrees / {max_trees} count) if numTrees > 0 count else 0
  growthRate.step = ({base_growth} percent + postFireBonus) * (1 - treeSuppression)
  netGrowth.step = growthRate * (1 - prior.invasiveCover / 100 percent) - activeRemoval

  rawCover.step = prior.invasiveCover + netGrowth
  invasiveCover.step = 0 percent if rawCover < 0 percent else (100 percent if rawCover > 100 percent else rawCover)

  export.numSeedling.step = count(NativeTree[NativeTree.state == "Seedling"])
  export.numJuvenile.step = count(NativeTree[NativeTree.state == "Juvenile"])
  export.numAdult.step = count(NativeTree[NativeTree.state == "Adult"])
  export.numAlive.step = count(NativeTree[NativeTree.alive == true])
  export.invasiveCover.step = invasiveCover
  export.newSeedlings.step = actualNewSeedlings
  export.fireSeverity.init = fireSeverity

end patch

start organism NativeTree

  age.init = sample uniform from {age_min} years to {age_max} years
  state.init = "Adult" if age >= {juvenile_to_adult} years else ("Juvenile" if age >= {seedling_to_juvenile} years else "Seedling")

  fireDeathRoll.init = sample uniform from 0 percent to 100 percent
  fireMortality.init = {fire_mortality}
  alive.init = fireDeathRoll > fireMortality

  age.step = prior.age + 1 year

  start state "Seedling"
    baseMortality.step = {seedling_mortality} percent
    invasivePressure.step = {seedling_invasive_pressure} percent if here.invasiveCover > {invasive_pressure_threshold} percent else 0 percent
    totalMortality.step = baseMortality + invasivePressure

    deathRoll.step = sample uniform from 0 percent to 100 percent
    alive.step = deathRoll > totalMortality

    state.step:if(current.age >= {seedling_to_juvenile} years and current.alive == true) = "Juvenile"
  end state

  start state "Juvenile"
    deathRoll.step = sample uniform from 0 percent to 100 percent
    alive.step = deathRoll > {juvenile_mortality} percent

    state.step:if(current.age >= {juvenile_to_adult} years and current.alive == true) = "Adult"
  end state

  start state "Adult"
    deathRoll.step = sample uniform from 0 percent to 100 percent
    alive.step = deathRoll > {adult_mortality} percent
  end state

end organism
'''
    return model


def run_scenario(scenario_name, has_fire, seeding_boost, removal_effort, params):
    """Generate model and run simulation."""

    print(f"\n{'='*60}")
    print(f"Running scenario: {scenario_name}")
    print(f"  Fire: {'Yes' if has_fire else 'No'}")
    print(f"  Seeding: {seeding_boost} trees/patch")
    print(f"  Removal: {removal_effort}%/year")
    print('='*60)

    # Generate model
    model_content = generate_model(scenario_name, has_fire, seeding_boost, removal_effort, params)
    model_path = f"/workspace/scenario_{scenario_name}.josh"

    with open(model_path, 'w') as f:
        f.write(model_content)

    # Build run command
    cmd = [
        "pixi", "run", "java", "-jar", "jar/joshsim-fat-prod.jar",
        "run", model_path, "Main",
        f"--data", f"data.jshd={FIRE_DATA}",
    ]

    result = subprocess.run(cmd, capture_output=True, text=True)

    if result.returncode != 0:
        print(f"ERROR: {result.stderr}")
        return False

    print(result.stdout)
    return True


def combine_results():
    """Combine all scenario results into a single CSV."""
    combined_path = f"{RESULTS_DIR}/all_scenarios_combined.csv"
    all_rows = []
    header = None

    for scenario_name, _, _, _ in SCENARIOS:
        result_file = f"{RESULTS_DIR}/{scenario_name}_0.csv"
        if not os.path.exists(result_file):
            print(f"Warning: {result_file} not found")
            continue

        with open(result_file, 'r') as f:
            reader = csv.DictReader(f)
            if header is None:
                header = reader.fieldnames + ['scenario']
            for row in reader:
                row['scenario'] = scenario_name
                all_rows.append(row)

    if all_rows:
        with open(combined_path, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=header)
            writer.writeheader()
            writer.writerows(all_rows)
        print(f"\nCombined {len(all_rows)} rows into {combined_path}")

    return combined_path


def main():
    print("Post-Fire Vegetation Recovery: Scenario Comparison")
    print("="*60)

    # Load parameters from config
    params = parse_jshc(PARAMS_CONFIG)
    print(f"Loaded {len(params)} parameters from {PARAMS_CONFIG}")

    # Key parameters
    print(f"  Fire high invasive cover: {params['fireHighInvasiveCover'][0]}%")
    print(f"  Fire medium invasive cover: {params['fireMediumInvasiveCover'][0]}%")
    print(f"  Fire low invasive cover: {params['fireLowInvasiveCover'][0]}%")
    print(f"  Establishment threshold: {params['establishmentThreshold'][0]}%")
    print("="*60)

    os.makedirs(RESULTS_DIR, exist_ok=True)

    success_count = 0
    for scenario_name, has_fire, seeding_boost, removal_effort in SCENARIOS:
        if run_scenario(scenario_name, has_fire, seeding_boost, removal_effort, params):
            success_count += 1

    print(f"\n{'='*60}")
    print(f"Completed {success_count}/{len(SCENARIOS)} scenarios")

    if success_count > 0:
        combine_results()

    print("\n" + "="*60)
    print("Run 'pixi run Rscript analysis/visualizations.R' to generate figures")
    print("="*60)


if __name__ == "__main__":
    main()

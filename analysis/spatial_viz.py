#!/usr/bin/env python3
"""
Spatial visualization of post-fire vegetation recovery scenarios.

Creates:
1. Static heatmaps showing final state for each scenario
2. Animated GIFs showing simulation evolution through time
"""

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')  # Use non-interactive backend
import matplotlib.pyplot as plt
import matplotlib.colors as mcolors
from matplotlib.gridspec import GridSpec
import os
import io

# Try to import imageio for GIF creation
try:
    import imageio.v2 as imageio
    HAS_IMAGEIO = True
except ImportError:
    try:
        import imageio
        HAS_IMAGEIO = True
    except ImportError:
        HAS_IMAGEIO = False
        print("Warning: imageio not available, GIFs will not be created")

# Output directory
os.makedirs("analysis/figures/spatial", exist_ok=True)

# Scenarios
SCENARIOS = ["baseline", "fire_only", "fire_seeding", "fire_removal", "fire_both"]
SCENARIO_LABELS = {
    "baseline": "Baseline (No Fire)",
    "fire_only": "Fire Only",
    "fire_seeding": "Fire + Seeding",
    "fire_removal": "Fire + Removal",
    "fire_both": "Fire + Both"
}

def load_scenario_data(scenario):
    """Load data for a scenario."""
    filepath = f"results/{scenario}_0.csv"
    if not os.path.exists(filepath):
        print(f"Warning: {filepath} not found")
        return None
    return pd.read_csv(filepath)

def create_grid(df, step, metric):
    """Create a 2D grid from dataframe for a given step and metric."""
    step_data = df[df['step'] == step].copy()

    # Get grid dimensions
    x_vals = sorted(step_data['position.x'].unique())
    y_vals = sorted(step_data['position.y'].unique())

    # Create grid
    grid = np.full((len(y_vals), len(x_vals)), np.nan)

    for _, row in step_data.iterrows():
        xi = x_vals.index(row['position.x'])
        yi = y_vals.index(row['position.y'])
        grid[yi, xi] = row[metric]

    return grid, x_vals, y_vals

def plot_final_state_comparison():
    """Create a figure comparing final state across all scenarios."""

    fig = plt.figure(figsize=(20, 8))
    gs = GridSpec(2, 5, figure=fig, hspace=0.3, wspace=0.1)

    for i, scenario in enumerate(SCENARIOS):
        df = load_scenario_data(scenario)
        if df is None:
            continue

        max_step = df['step'].max()

        # Tree population (top row)
        ax1 = fig.add_subplot(gs[0, i])
        grid, x_vals, y_vals = create_grid(df, max_step, 'numAlive')
        im1 = ax1.imshow(grid, cmap='YlGn', vmin=0, vmax=10, origin='lower')
        ax1.set_title(SCENARIO_LABELS[scenario], fontsize=10, fontweight='bold')
        if i == 0:
            ax1.set_ylabel('Trees per Patch', fontsize=11)
        ax1.set_xticks([])
        ax1.set_yticks([])

        # Invasive cover (bottom row)
        ax2 = fig.add_subplot(gs[1, i])
        grid, x_vals, y_vals = create_grid(df, max_step, 'invasiveCover')
        im2 = ax2.imshow(grid * 100, cmap='YlOrRd', vmin=0, vmax=100, origin='lower')
        if i == 0:
            ax2.set_ylabel('Invasive Cover (%)', fontsize=11)
        ax2.set_xticks([])
        ax2.set_yticks([])

    # Add colorbars
    cbar_ax1 = fig.add_axes([0.92, 0.55, 0.01, 0.35])
    fig.colorbar(im1, cax=cbar_ax1, label='Trees')

    cbar_ax2 = fig.add_axes([0.92, 0.1, 0.01, 0.35])
    fig.colorbar(im2, cax=cbar_ax2, label='Cover (%)')

    fig.suptitle('Final State (Year 50): Spatial Distribution Across Scenarios',
                 fontsize=14, fontweight='bold', y=0.98)

    plt.savefig('analysis/figures/spatial/final_state_comparison.png',
                dpi=150, bbox_inches='tight')
    plt.close()
    print("Saved: final_state_comparison.png")

def plot_fire_severity_map():
    """Plot the fire severity map used in simulations."""

    df = load_scenario_data("fire_only")
    if df is None:
        return

    fig, ax = plt.subplots(figsize=(8, 8))
    grid, x_vals, y_vals = create_grid(df, 0, 'fireSeverity')

    im = ax.imshow(grid, cmap='hot_r', vmin=0, vmax=1, origin='lower')
    ax.set_title('Fire Severity Map\n(Used for all fire scenarios)', fontsize=12, fontweight='bold')
    ax.set_xlabel('X Position')
    ax.set_ylabel('Y Position')

    cbar = plt.colorbar(im, ax=ax, shrink=0.8)
    cbar.set_label('Fire Severity (0-1)')

    plt.savefig('analysis/figures/spatial/fire_severity_spatial.png',
                dpi=150, bbox_inches='tight')
    plt.close()
    print("Saved: fire_severity_spatial.png")

def create_scenario_gif(scenario, metric='numAlive', fps=5):
    """Create an animated GIF for a single scenario."""

    if not HAS_IMAGEIO:
        return

    df = load_scenario_data(scenario)
    if df is None:
        return

    steps = sorted(df['step'].unique())
    frames = []

    # Set up colormap and limits based on metric
    if metric == 'numAlive':
        cmap = 'YlGn'
        vmin, vmax = 0, 10
        label = 'Trees per Patch'
    else:  # invasiveCover
        cmap = 'YlOrRd'
        vmin, vmax = 0, 100
        label = 'Invasive Cover (%)'

    for step in steps:
        fig, ax = plt.subplots(figsize=(6, 6))

        grid, x_vals, y_vals = create_grid(df, step, metric)
        if metric == 'invasiveCover':
            grid = grid * 100  # Convert to percentage

        im = ax.imshow(grid, cmap=cmap, vmin=vmin, vmax=vmax, origin='lower')
        ax.set_title(f'{SCENARIO_LABELS[scenario]}\nYear {step}', fontsize=12, fontweight='bold')
        ax.set_xticks([])
        ax.set_yticks([])

        cbar = plt.colorbar(im, ax=ax, shrink=0.8)
        cbar.set_label(label)

        # Save frame to buffer
        buf = io.BytesIO()
        fig.savefig(buf, format='png', dpi=100, bbox_inches='tight')
        buf.seek(0)
        frame = imageio.imread(buf)
        frames.append(frame)
        buf.close()
        plt.close()

    # Save GIF
    metric_name = 'trees' if metric == 'numAlive' else 'invasive'
    gif_path = f'analysis/figures/spatial/{scenario}_{metric_name}.gif'
    imageio.mimsave(gif_path, frames, fps=fps, loop=0)
    print(f"Saved: {scenario}_{metric_name}.gif")

def create_combined_gif(metric='numAlive', fps=5):
    """Create a combined GIF showing all scenarios side by side."""

    if not HAS_IMAGEIO:
        return

    # Load all scenario data
    all_data = {}
    for scenario in SCENARIOS:
        df = load_scenario_data(scenario)
        if df is not None:
            all_data[scenario] = df

    if not all_data:
        return

    steps = sorted(list(all_data.values())[0]['step'].unique())
    frames = []

    # Set up colormap and limits
    if metric == 'numAlive':
        cmap = 'YlGn'
        vmin, vmax = 0, 10
        label = 'Trees per Patch'
        title_metric = 'Tree Population'
    else:
        cmap = 'YlOrRd'
        vmin, vmax = 0, 100
        label = 'Invasive Cover (%)'
        title_metric = 'Invasive Cover'

    for step in steps:
        fig, axes = plt.subplots(1, 5, figsize=(18, 4))

        for i, scenario in enumerate(SCENARIOS):
            if scenario not in all_data:
                continue

            df = all_data[scenario]
            grid, x_vals, y_vals = create_grid(df, step, metric)
            if metric == 'invasiveCover':
                grid = grid * 100

            im = axes[i].imshow(grid, cmap=cmap, vmin=vmin, vmax=vmax, origin='lower')
            axes[i].set_title(SCENARIO_LABELS[scenario], fontsize=9, fontweight='bold')
            axes[i].set_xticks([])
            axes[i].set_yticks([])

        # Add colorbar
        cbar_ax = fig.add_axes([0.92, 0.15, 0.01, 0.7])
        fig.colorbar(im, cax=cbar_ax, label=label)

        fig.suptitle(f'{title_metric} Evolution - Year {step}',
                    fontsize=12, fontweight='bold')

        # Save frame to buffer
        buf = io.BytesIO()
        fig.savefig(buf, format='png', dpi=100, bbox_inches='tight')
        buf.seek(0)
        frame = imageio.imread(buf)
        frames.append(frame)
        buf.close()
        plt.close()

    # Save GIF
    metric_name = 'trees' if metric == 'numAlive' else 'invasive'
    gif_path = f'analysis/figures/spatial/all_scenarios_{metric_name}.gif'
    imageio.mimsave(gif_path, frames, fps=fps, loop=0)
    print(f"Saved: all_scenarios_{metric_name}.gif")

def main():
    print("Generating spatial visualizations...")
    print("=" * 50)

    # Static comparisons
    plot_final_state_comparison()
    plot_fire_severity_map()

    # Animated GIFs
    if HAS_IMAGEIO:
        print("\nGenerating animated GIFs (this may take a moment)...")

        # Combined GIFs for all scenarios
        create_combined_gif(metric='numAlive', fps=5)
        create_combined_gif(metric='invasiveCover', fps=5)

        # Individual scenario GIFs (just for key scenarios)
        for scenario in ['fire_only', 'fire_removal']:
            create_scenario_gif(scenario, metric='numAlive', fps=5)
            create_scenario_gif(scenario, metric='invasiveCover', fps=5)

    print("\n" + "=" * 50)
    print("All spatial visualizations saved to analysis/figures/spatial/")
    print("=" * 50)

if __name__ == "__main__":
    main()

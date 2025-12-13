# Josh Toolbox Demo

Complete end-to-end demonstration of post-fire vegetation recovery workflow using **Pixi** for unified dependency management.

## Why Pixi?

- **Single tool** manages Python, R, and Java
- **Reproducible** environments via `pixi.lock`
- **Fast** installations using conda-forge
- **Simple** declarative configuration in `pixi.toml`

## Quick Start

### Option 1: Using Pixi locally

```bash
# Install pixi (if not already installed)
curl -fsSL https://pixi.sh/install.sh | bash

# Install all dependencies (Python, R, Java, packages)
pixi install

# Start Jupyter Lab
pixi run jupyter

# Or run individual tasks
pixi run demo      # Execute the notebook
pixi run visualize # Run R visualizations
```

### Option 2: Using Docker

```bash
# Build and run
docker build -t josh-toolbox-demo .
docker run -it -v $(pwd):/workspace -p 8888:8888 josh-toolbox-demo
```

### Option 3: Dev Container

Open in VS Code and "Reopen in Container"

## What's Included

All dependencies declared in `pixi.toml`:

**Python Stack:**
- numpy, pandas, matplotlib, rasterio
- jupyter, jupyterlab

**R Stack:**
- r-base (4.3+)
- r-tidyverse, r-scales, r-patchwork

**Java:**
- OpenJDK 21 (for Josh simulation engine)

## Managing Dependencies

```bash
# Add a new Python package
pixi add scipy

# Add a new R package
pixi add r-ggplot2

# Update all packages
pixi update

# Lock dependencies
pixi install --locked
```

## Running the Workflow

```bash
# 1. Start Jupyter and run the notebook interactively
pixi run jupyter

# 2. Or execute the entire workflow
pixi run demo

# 3. Generate final visualizations
pixi run visualize
```

## File Structure

- `pixi.toml` - Dependency specifications and tasks
- `pixi.lock` - Locked dependency versions (committed to git)
- `Dockerfile.pixi` - Multi-stage Docker build
- `demo_workflow.ipynb` - Main workflow notebook
- `analysis/visualizations.R` - R visualization script

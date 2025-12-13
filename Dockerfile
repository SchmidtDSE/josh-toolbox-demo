# Simple pixi-based container
FROM ghcr.io/prefix-dev/pixi:latest

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy pixi configuration
WORKDIR /workspace
COPY pixi.toml pixi.lock* ./

# Install dependencies
RUN pixi install

# Expose Jupyter port
EXPOSE 8888

# Default command
CMD ["pixi", "run", "jupyter"]

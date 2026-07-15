FROM python:3.11-slim

# Install system dependencies (no recommended extras, clean apt cache)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install Databricks CLI (official Go-based CLI)
RUN curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh

WORKDIR /workspace

# Install pinned Python packages for reproducible builds
RUN pip install --no-cache-dir \
    dbt-core==1.8.0 \
    dbt-databricks==1.8.0 \
    ruff==0.4.0 \
    sqlfluff==3.0.0 \
    streamlit==1.35.0 \
    databricks-sdk==0.17.0

# Keep the container alive indefinitely so we can manually exec into it
CMD ["tail", "-f", "/dev/null"]
# =============================================================================
# ai-codeserver-env — Dockerfile
# =============================================================================
#
# Purpose:
#   Build a browser-based VS Code development workstation (code-server) with
#   Node.js LTS, pnpm, Git, GitHub CLI, Claude Code, and Playwright.
#
# Designed for:
#   - Local testing via docker-compose.yaml
#   - Production deployment on Coolify v4+ (build pack: Dockerfile)
#
# Base image:
#   codercom/code-server — the official code-server distribution.
#   It already ships with:
#     - code-server binary
#     - a non-root "coder" user (UID 1000)
#     - a sensible default filesystem layout under /home/coder
#
# Security notes (V1):
#   - Runs as non-root user "coder" (switched back after root-only setup steps)
#   - NO Docker CLI installed
#   - NO /var/run/docker.sock mount — manage containers through Coolify instead
#
# Build:
#   docker build -t ai-codeserver-env .
#
# Coolify:
#   Build Pack  → Docker Compose (recommended) — reads docker-compose.yaml
#   Alternative → Dockerfile build pack (manual volumes + password)
#   Port        → 8080 (via expose: in compose, or Ports Exposes in UI)
# =============================================================================

# -----------------------------------------------------------------------------
# STAGE: Base image
# -----------------------------------------------------------------------------
# Pin to "latest" for simplicity in V1. For production hardening, consider
# pinning a specific tag (e.g. codercom/code-server:4.96.2) so rebuilds are
# reproducible and you control when the base image changes.
FROM codercom/code-server:latest

# -----------------------------------------------------------------------------
# Switch to root for system-level package installation
# -----------------------------------------------------------------------------
# The code-server image runs as "coder" by default. We need root to install
# apt packages, Node.js, and system-level Playwright dependencies.
USER root

# Prevent apt from prompting for input during unattended installs (required in
# non-interactive Docker builds).
ENV DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# System packages
# -----------------------------------------------------------------------------
# Minimal set of tools needed by this image and common dev workflows:
#   - ca-certificates : HTTPS/TLS for curl, npm, gh, etc.
#   - curl            : downloading install scripts (NodeSource, GitHub CLI)
#   - git             : version control (also used by VS Code Git integration)
#   - gnupg           : required by apt for signed repositories (GitHub CLI repo)
#   - sudo            : occasionally useful inside the dev environment
#
# --no-install-recommends keeps the image smaller by skipping suggested packages.
# rm -rf /var/lib/apt/lists/* clears the apt cache to reduce layer size.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    gnupg \
    gosu \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Node.js LTS (via NodeSource)
# -----------------------------------------------------------------------------
# Installs the current Node.js LTS release (major version tracks NodeSource's
# setup_lts.x script — e.g. Node 22 LTS at time of writing).
#
# Why NodeSource instead of the base image's Node?
#   The code-server base image does not include Node.js. We need it for pnpm,
#   npm global packages (Claude Code), and general web development.
#
# The setup script adds the NodeSource apt repository, then we install nodejs.
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Global Node.js CLIs
# -----------------------------------------------------------------------------
#   - pnpm          : fast, disk-efficient package manager (alongside built-in npm)
#   - @anthropic-ai/claude-code : Anthropic's terminal-based AI coding agent
#
# Installed globally so they are available in any terminal session and project.
RUN npm install -g pnpm @anthropic-ai/claude-code

# -----------------------------------------------------------------------------
# GitHub CLI (gh)
# -----------------------------------------------------------------------------
# Official Debian package from GitHub's apt repository.
# Used for: gh auth login, PRs, issues, repo cloning with credentials, etc.
#
# Steps:
#   1. Import GitHub's GPG key into apt's keyring
#   2. Add the GitHub CLI apt source (architecture-aware)
#   3. Install the gh package
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Playwright — system dependencies (Chromium only)
# -----------------------------------------------------------------------------
# Playwright needs OS-level libraries (fonts, libgbm, libnss3, etc.) to run
# headless Chromium. `install-deps chromium` installs only what Chromium needs.
#
# We install ONLY Chromium (not Firefox/WebKit) to keep the image smaller.
# This command must run as root (system packages).
#
# Note: browser binaries themselves are installed later as the "coder" user.
RUN npx --yes playwright install-deps chromium

# -----------------------------------------------------------------------------
# Copy configuration files and entrypoint script
# -----------------------------------------------------------------------------
# config/ contains:
#   - extensions.txt : VS Code extension IDs (installed at container start)
#   - settings.json  : default VS Code user settings (copied on first run)
#
# These are placed in /etc/codeserver/ (read-only, baked into the image).
# The entrypoint script reads from there and writes to the coder user's home
# directory (which may be backed by a persistent volume in production).
COPY config/ /etc/codeserver/
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

# Make entrypoint executable, ensure workspace exists, fix ownership.
# /home/coder/workspace is the default code-server workspace opened on login.
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && mkdir -p /home/coder/workspace \
    && chown -R coder:coder /home/coder

# -----------------------------------------------------------------------------
# Switch back to non-root user
# -----------------------------------------------------------------------------
# Security best practice: the running container should not be root.
# Coolify and docker-compose both run this container as UID 1000 (coder).
# Entrypoint runs as root to fix volume permissions, then drops to coder via gosu.
# Playwright browsers above remain owned by coder (installed in USER coder step).
USER root
WORKDIR /home/coder

# -----------------------------------------------------------------------------
# Playwright — browser binaries (Chromium only)
# -----------------------------------------------------------------------------
# Downloads the Chromium binary to ~/.cache/ms-playwright/ for the coder user.
# Must run AFTER switching to USER coder so files are owned by the right user.
#
# If this step ran as root, Playwright would install browsers in /root/.cache/
# and the coder user would not find them.
RUN npx --yes playwright install chromium

# -----------------------------------------------------------------------------
# Network
# -----------------------------------------------------------------------------
# Inform Docker (and Coolify) that the application listens on port 8080.
# The entrypoint binds code-server to 0.0.0.0:8080 (all interfaces).
#
# In Coolify → General → "Ports Exposes": set to 8080
# Coolify's Traefik proxy routes HTTPS traffic to this internal port.
EXPOSE 8080

# -----------------------------------------------------------------------------
# Container entrypoint
# -----------------------------------------------------------------------------
# The entrypoint script:
#   1. Copies default settings.json on first run (if no user settings exist)
#   2. Installs VS Code extensions from extensions.txt (first run, or on demand)
#   3. Starts code-server bound to 0.0.0.0:8080 with /home/coder/workspace
#
# Environment variables consumed at runtime:
#   PASSWORD                    — code-server login password (required)
#   OPTIONAL_EXTENSION_UPDATE   — "true" to re-install extensions every start
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

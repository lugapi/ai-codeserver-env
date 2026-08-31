# ai-codeserver-env

A production-ready **code-server** development workstation image designed for self-hosted VPS deployments with [Coolify](https://coolify.io).

Open a full VS Code experience in your browser, pre-loaded with the tools you need for modern web development and AI-assisted coding — without Docker-in-Docker or host socket access.

---

## Table of contents

- [What's included](#whats-included)
- [What's intentionally excluded (V1)](#whats-intentionally-excluded-v1)
- [Architecture](#architecture)
- [Quick start (local)](#quick-start-local)
- [Deploying on Coolify](#deploying-on-coolify)
  - [Prerequisites](#prerequisites)
  - [Step 1 — Fork or clone this repository](#step-1--fork-or-clone-this-repository)
  - [Step 2 — Create a new resource in Coolify](#step-2--create-a-new-resource-in-coolify)
  - [Step 3 — Configure the build](#step-3--configure-the-build)
  - [Step 4 — Set environment variables](#step-4--set-environment-variables)
  - [Step 5 — Configure persistent storage](#step-5--configure-persistent-storage)
  - [Step 6 — Configure networking & SSL](#step-6--configure-networking--ssl)
  - [Step 7 — Deploy](#step-7--deploy)
  - [Step 8 — First login & setup](#step-8--first-login--setup)
- [VS Code extensions](#vs-code-extensions)
- [Authentication & CLI setup](#authentication--cli-setup)
- [Updating the environment](#updating-the-environment)
- [Security recommendations](#security-recommendations)
- [Troubleshooting](#troubleshooting)
- [Roadmap](#roadmap)
- [License](#license)

---

## What's included

| Tool | Purpose |
|------|---------|
| [code-server](https://github.com/coder/code-server) | VS Code in the browser |
| **Node.js LTS** | JavaScript / TypeScript runtime |
| **npm** | Default Node package manager (ships with Node) |
| **pnpm** | Fast, disk-efficient package manager |
| **Git** | Version control |
| [GitHub CLI (`gh`)](https://cli.github.com/) | GitHub from the terminal (PRs, issues, auth) |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | Anthropic's AI coding agent in the terminal |
| [Playwright](https://playwright.dev/) | End-to-end browser testing (Chromium pre-installed) |
| **Pre-configured VS Code extensions** | See [extensions list](#vs-code-extensions) |

The container runs as a **non-root** user (`coder`, UID 1000).

---

## What's intentionally excluded (V1)

| Excluded | Reason |
|----------|--------|
| Docker CLI | Not needed when Coolify manages containers; mounting the Docker socket grants near-root access to the entire host |
| `/var/run/docker.sock` mount | Security risk for a browser-exposed dev environment |

**Manage containers through Coolify** — view logs, restart services, deploy apps. Docker CLI support may be added later as an opt-in build variant for advanced automation (e.g. a future Coolify MCP integration).

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  VPS (single Docker Engine)                             │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │   Coolify    │  │  PostgreSQL  │  │  Your apps    │  │
│  └──────────────┘  └──────────────┘  └───────────────┘  │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │  ai-codeserver-env  (this image)                 │   │
│  │                                                  │   │
│  │  code-server ──► Node LTS, pnpm, Git, gh,       │   │
│  │                  Claude Code, Playwright         │   │
│  │                                                  │   │
│  │  Persistent volumes:                             │   │
│  │    ~/.local/share/code-server  (extensions)    │   │
│  │    ~/.config/code-server       (server config)   │   │
│  │    ~/workspace                 (your projects)   │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  Traefik / Coolify proxy ──► HTTPS ──► your browser    │
└─────────────────────────────────────────────────────────┘
```

---

## Quick start (local)

Test the image on your machine before deploying to Coolify.

### 1. Clone the repository

```bash
git clone https://github.com/lugapi/ai-codeserver-env.git
cd ai-codeserver-env
```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and set a strong `PASSWORD`.

### 3. Build and run (local override)

```bash
docker compose -f docker-compose.yaml -f docker-compose.local.yml up -d --build
```

> The base `docker-compose.yaml` is optimized for Coolify (no host port, magic password variable).
> `docker-compose.local.yml` adds the port mapping and reads `PASSWORD` from your `.env`.

### 4. Open in browser

Navigate to [http://localhost:8080](http://localhost:8080) and log in with your `PASSWORD`.

### 5. Stop

```bash
docker compose -f docker-compose.yaml -f docker-compose.local.yml down
```

To also remove persistent volumes:

```bash
docker compose -f docker-compose.yaml -f docker-compose.local.yml down -v
```

---

## Deploying on Coolify

This guide is written for **Coolify v4** (tested against **v4.3.14**). It walks you through deploying `ai-codeserver-env` as a Git-based **Application** on your VPS.

Official Coolify references:

- [Deploy a public GitHub repository](https://coolify.io/docs/applications/ci-cd/github/public-repository)
- [Docker Compose build pack](https://coolify.io/docs/applications/build-packs/docker-compose)
- [Coolify magic environment variables](https://coolify.io/docs/knowledge-base/docker/compose#coolifys-magic-environment-variables)
- [General application settings](https://coolify.io/docs/applications/configuration/general)

### Dockerfile vs Docker Compose — which build pack?

Both work. **Docker Compose is recommended** for this repo because `docker-compose.yaml` already declares everything Coolify would otherwise ask you to configure manually:

| | **Docker Compose** (recommended) | **Dockerfile** (alternative) |
|---|----------------------------------|------------------------------|
| Persistent volumes | Defined in `docker-compose.yaml` — created automatically | Must add 3 mounts manually in Coolify UI |
| `PASSWORD` | Auto-generated via `SERVICE_PASSWORD_CODESERVER` magic var | Must set manually (`openssl rand -base64 32`) |
| Health check | Defined in `docker-compose.yaml` | Configure in Coolify UI |
| Port | `expose: 8080` in compose — Traefik routes traffic | Set **Ports Exposes** = `8080` in General tab |
| Local testing | Same `docker-compose.yaml` + `docker-compose.local.yml` | `docker compose` with local override |

> **Important:** Create an **Application** with build pack **Docker Compose** — not a **Service** (one-click template). The compose file lives in your Git repo; Coolify clones it and deploys the stack.

### Prerequisites

- A VPS with **Coolify v4** installed and running (v4.3.14 or later)
- Your VPS added as a **server** in Coolify
- A domain or subdomain with a DNS **A record** pointing to your VPS IP (e.g. `code.yourdomain.com`)
- This repository pushed to **GitHub** as a **public** repository at `https://github.com/lugapi/ai-codeserver-env`

> **Private repo?** Use a [GitHub App](https://coolify.io/docs/applications/ci-cd/github/setup-github-app) or [deploy key](https://coolify.io/docs/applications/ci-cd/github/deploy-key) instead of the public URL flow.

### Step 1 — Push the repository to GitHub

```bash
git init
git add .
git commit -m "Initial commit: code-server dev workstation for Coolify"
gh repo create ai-codeserver-env --public --source=. --push
```

Your repo URL will be:

```
https://github.com/lugapi/ai-codeserver-env
```

### Step 2 — Create a new Application in Coolify

1. Open your **Coolify dashboard**
2. Go to **Projects** → select (or create) a project
3. Select the target **environment** (e.g. `production`)
4. Click **+ New** (or **+ New Resource**)
5. Under **Applications**, choose **Public Repository**
6. Paste the repository URL:
   ```
   https://github.com/lugapi/ai-codeserver-env
   ```
7. Select the branch: `main`
8. Click **Continue** / **Create**

### Step 3 — Configure the build (General tab)

Open the application → **Configuration** → **General**.

| Coolify field | Value | Notes |
|---------------|-------|-------|
| **Build Pack** | `Docker Compose` | Coolify reads `docker-compose.yaml` at repo root |
| **Base Directory** | `/` | Repository root |
| **Docker Compose Location** | `/docker-compose.yaml` | Default if file is at root |
| **Domains** | `https://code.yourdomain.com` | Your FQDN with `https://` prefix |

> Coolify may auto-detect Docker Compose because `docker-compose.yaml` exists at the root. If it picked Nixpacks or Dockerfile, **manually switch** to Docker Compose.

> You do **not** need to set Ports Exposes, Persistent Storage, or PASSWORD manually — they come from `docker-compose.yaml`.

Click **Save**.

### Step 4 — Deploy

1. Click **Deploy**
2. Watch build logs in the **Deployments** tab (first build: 5–10 minutes)
3. Application status should turn **running** (green)

What Coolify does:

1. Clones `https://github.com/lugapi/ai-codeserver-env`
2. Reads `docker-compose.yaml`
3. Builds the image from `./Dockerfile`
4. Generates `SERVICE_PASSWORD_CODESERVER` (magic variable) and injects it as `PASSWORD`
5. Creates the three named volumes (`code-server-data`, `code-server-config`, `workspace`)
6. Starts the container and routes your domain via Traefik + Let's Encrypt

### Step 5 — Find your auto-generated password

Coolify generated the password for you. To retrieve it:

1. Go to **Configuration** → **Environment Variables**
2. Look for `SERVICE_PASSWORD_CODESERVER` (or check the resolved `PASSWORD` value)
3. Copy it — you'll need it to log in to code-server

No `openssl rand` required.

### Step 6 — Verify HTTPS and login

1. Open `https://code.yourdomain.com`
2. Enter the auto-generated `PASSWORD`
3. On first start, VS Code extensions install from `config/extensions.txt` (1–2 minutes)
4. Workspace opens at `/home/coder/workspace`

### Coolify settings cheat sheet (Docker Compose — recommended)

```
Resource type:     Application
Source:            Public Repository
Repository:        https://github.com/lugapi/ai-codeserver-env
Branch:            main

General:
  Build Pack:              Docker Compose
  Base Directory:          /
  Docker Compose Location: /docker-compose.yaml
  Domains:                 https://code.yourdomain.com

Environment Variables:   (auto-generated by Coolify)
  SERVICE_PASSWORD_CODESERVER → injected as PASSWORD

Persistent Storage:      (defined in docker-compose.yaml — no manual setup)
  code-server-data   → /home/coder/.local/share/code-server
  code-server-config → /home/coder/.config/code-server
  workspace          → /home/coder/workspace
  coder-ssh          → /home/coder/.ssh  (GitHub SSH keys)

Health Checks:           (defined in docker-compose.yaml)
  GET /healthz on port 8080
```

---

### Alternative: Dockerfile build pack

If you prefer the Dockerfile-only path (or already created the app with that build pack):

| Coolify field | Value |
|---------------|-------|
| **Build Pack** | `Dockerfile` |
| **Dockerfile Location** | `/Dockerfile` |
| **Ports Exposes** | `8080` |
| **Domains** | `https://code.yourdomain.com` |

Then manually:

1. **Environment Variables** → set `PASSWORD` (generate with `openssl rand -base64 32`)
2. **Persistent Storage** → add 3 volume mounts (paths listed in cheat sheet above)
3. **Health Checks** → path `/healthz`, port `8080`

> You cannot switch build pack on an existing application. Delete and recreate if you want to change.

### Redeploying after changes

When you push changes to GitHub (new extensions, Dockerfile updates, etc.):

1. **Manual:** Click **Deploy** in Coolify
2. **Automatic:** Enable auto-deploy via a [GitHub webhook](https://coolify.io/docs/applications/ci-cd/github/auto-deploy) or [GitHub App](https://coolify.io/docs/applications/ci-cd/github/setup-github-app)

Persistent volumes are preserved across redeploys — your workspace and settings survive.

### First login & setup

#### Clone a project

Open the integrated terminal (`Ctrl+`` `) and clone your repos:

```bash
cd ~/workspace
git clone https://github.com/your-org/your-project.git
cd your-project
pnpm install
```

#### Authenticate GitHub CLI

```bash
gh auth login
```

Follow the interactive prompts (browser-based OAuth works well).

#### Authenticate Claude Code

```bash
claude
```

Follow the Anthropic authentication flow on first use.

---

## VS Code extensions

Extensions are defined in [`config/extensions.txt`](config/extensions.txt) and installed automatically on the **first container start** (or on every start if `OPTIONAL_EXTENSION_UPDATE=true`).

### Default extensions

| Extension | ID |
|-----------|-----|
| Prettier | `esbenp.prettier-vscode` |
| ESLint | `dbaeumer.vscode-eslint` |
| GitLens | `eamodio.gitlens` |
| Error Lens | `usernamehw.errorlens` |
| TypeScript (next) | `ms-vscode.vscode-typescript-next` |
| Tailwind CSS IntelliSense | `bradlc.vscode-tailwindcss` |
| Auto Rename Tag | `formulahendry.auto-rename-tag` |
| Path Intellisense | `christian-kohler.path-intellisense` |
| GitHub Pull Requests | `GitHub.vscode-pull-request-github` |
| Claude Code | `anthropic.claude-code` |
| EditorConfig | `EditorConfig.EditorConfig` |
| DotENV | `mikestead.dotenv` |

### How extension updates work

Extensions are **not** auto-updated silently in the background. This is intentional — you stay in control of what runs in your environment.

| Method | When to use |
|--------|-------------|
| **First-run install** (default) | Extensions from `extensions.txt` are installed once, then persisted on the volume |
| **Redeploy after editing `extensions.txt`** | Add or remove extensions, then rebuild/redeploy in Coolify |
| **`OPTIONAL_EXTENSION_UPDATE=true`** | Force re-install/update all extensions on every container start (slower startups, always latest versions) |

To add an extension:

1. Find its ID on [Open VSX](https://open-vsx.org/) or the VS Code Marketplace
2. Add the ID to `config/extensions.txt`
3. Set `OPTIONAL_EXTENSION_UPDATE=true` for one deploy (or delete the marker file on the volume), then redeploy
4. Set it back to `false` afterward

### Customizing editor settings

Default settings live in [`config/settings.json`](config/settings.json). They are copied to the user's settings directory **only if no settings file exists yet**. After that, customize freely inside code-server — your changes persist on the volume.

---

## Authentication & CLI setup

| Tool | Setup command | Notes |
|------|---------------|-------|
| **code-server** | `PASSWORD` env var (or Coolify magic var) | Web UI login |
| **Git + GitHub** | SSH deploy key (recommended) | See below — revocable from GitHub |
| **GitHub CLI** | `gh auth login` | Optional — PRs, issues, API |
| **Claude Code** | `claude` | Authenticates on first run |
| **Git identity** | `git config --global user.name/email` | Required for commits |

---

## Connect GitHub with SSH (recommended)

Yes — you can (and should) use a **dedicated SSH key** instead of typing your GitHub password. The key is stored in `~/.ssh/`, which is persisted on the `coder-ssh` volume and survives redeploys.

**Revoking access:** delete the key from GitHub → code-server can no longer push or pull. No password to rotate.

### GitHub links (direct)

| Action | URL |
|--------|-----|
| **Add a deploy key** (one repo) | `https://github.com/lugapi/YOUR_REPO/settings/keys` |
| **Manage deploy keys** (revoke) | same URL → **Delete** next to the key |
| **Add an account SSH key** (all repos) | [github.com/settings/ssh/new](https://github.com/settings/ssh/new) |
| **Manage account SSH keys** (revoke) | [github.com/settings/keys](https://github.com/settings/keys) |
| **Revoke `gh` tokens** (if used) | [github.com/settings/tokens](https://github.com/settings/tokens) |
| **GitHub docs — deploy keys** | [docs.github.com → Managing deploy keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys) |

Replace `YOUR_REPO` with the target repository name (e.g. `https://github.com/lugapi/my-app/settings/keys`).

### SSH key vs other methods

| Method | Revocable? | Scope | Revoke here |
|--------|------------|-------|-------------|
| **SSH deploy key** (recommended) | Yes | One repository | [repo settings/keys](https://github.com/lugapi/YOUR_REPO/settings/keys) |
| **SSH key on your GitHub account** | Yes | All repos you can access | [github.com/settings/keys](https://github.com/settings/keys) |
| **`gh auth login`** | Yes | GitHub CLI + extension | [github.com/settings/tokens](https://github.com/settings/tokens) |
| **HTTPS + password/PAT** | Yes | Per-token scope | Avoid — use SSH instead |

For a VPS dev environment, **deploy keys** are the most secure: one key = one repo, read-only or read-write.

### Step 1 — Generate a key inside code-server

Open the integrated terminal in code-server:

```bash
# Create ~/.ssh with correct permissions (volume is empty on first run)
mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Generate a dedicated key — no passphrase (unattended git operations)
ssh-keygen -t ed25519 -C "codeserver-vps" -f ~/.ssh/github_codeserver -N ""

# Tell SSH to use this key for github.com
cat >> ~/.ssh/config << 'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/github_codeserver
  IdentitiesOnly yes
EOF
chmod 600 ~/.ssh/config ~/.ssh/github_codeserver
```

### Step 2 — Add the public key to GitHub

Print the public key:

```bash
cat ~/.ssh/github_codeserver.pub
```

Then on GitHub, choose **one** option:

#### Option A — Deploy key (recommended, one repo)

1. Open **[github.com/lugapi/YOUR_REPO/settings/keys](https://github.com/lugapi/YOUR_REPO/settings/keys)** (replace `YOUR_REPO`)
2. Click **Add deploy key**
3. Title: `code-server VPS`
4. Paste the public key
5. Check **Allow write access** only if you need `git push`
6. Click **Add key**

To revoke: same page → **Delete** next to the deploy key.

#### Option B — Account SSH key (all your repos)

1. Open **[github.com/settings/ssh/new](https://github.com/settings/ssh/new)**
2. Title: `code-server VPS`
3. Key type: **Authentication Key**
4. Paste the public key
5. Click **Add SSH key**

To revoke: **[github.com/settings/keys](https://github.com/settings/keys)** → **Delete** next to the key.

### Step 3 — Test the connection

```bash
ssh -T git@github.com
```

Expected output:

```
Hi lugapi! You've successfully authenticated, but GitHub does not provide shell access.
```

### Step 4 — Clone and work

```bash
cd ~/workspace
git clone git@github.com:lugapi/your-project.git
```

Use **SSH URLs** (`git@github.com:...`), not HTTPS (`https://github.com/...`).

### Configure Git identity (once)

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### Optional — GitHub CLI (`gh`)

For pull requests and issues from the terminal:

```bash
gh auth login
# Choose: GitHub.com → SSH → path to ~/.ssh/github_codeserver
```

You can use the same SSH key. To revoke CLI access: [github.com/settings/tokens](https://github.com/settings/tokens).

---

## Updating the environment

### Pull latest image changes

When this repository is updated (new tools, security patches):

1. In Coolify, click **Redeploy** on your resource
2. Coolify rebuilds the image from the latest commit and restarts the container
3. Your persistent volumes (extensions, workspace, settings) are preserved

### Update Node packages inside a project

```bash
cd ~/workspace/your-project
pnpm update
```

### Update global tools

Global tools (Node, pnpm, gh, Playwright, Claude Code) are baked into the Docker image. To get newer versions, rebuild the image from an updated `Dockerfile` commit.

---

## Security recommendations

This environment is exposed to the internet. Treat it accordingly.

1. **Use a strong `PASSWORD`** — at least 32 random characters
2. **Enable HTTPS** — always, via Coolify's Let's Encrypt integration
3. **Do not mount `/var/run/docker.sock`** — not in V1, not without understanding the risk
4. **Restrict network access** if possible — IP allowlist, VPN, or Tailscale
5. **Keep the image updated** — redeploy regularly to pick up base image security patches
6. **Do not store secrets in the workspace** — use Coolify environment variables or a secrets manager
7. **Review `config/extensions.txt`** before deploying — only install extensions you trust

---

## Troubleshooting

### Extensions not installing

- Check container logs in Coolify for `Installing extension:` messages
- Ensure the persistent volume for `/home/coder/.local/share/code-server` is mounted
- Try setting `OPTIONAL_EXTENSION_UPDATE=true`, redeploy, then set back to `false`
- Delete the marker file to force a fresh install:
  ```bash
  rm /home/coder/.local/share/code-server/.extensions-installed
  ```
  Then restart the container.

### Playwright tests fail with missing browser

Chromium is pre-installed at image build time. If tests fail:

```bash
npx playwright install chromium
```

### `pnpm: command not found`

Rebuild the image. pnpm is installed globally in the Dockerfile.

### Cannot access code-server after deploy

- Verify the domain DNS points to your VPS
- Check Coolify proxy is forwarding to port `8080`
- Check container health: `GET /healthz` should return `200`
- Review Coolify deployment logs for startup errors

### Container restart loop — `Permission denied` on `/home/coder/.local/...`

Docker named volumes are often created as **root**. The entrypoint fixes ownership on startup (`chown coder:coder`). If you still see this after updating:

1. **Redeploy** in Coolify to pull the latest image (includes the permission fix)
2. If it persists, delete the application volumes in Coolify and redeploy (you lose extensions/workspace data)

### Permission errors on workspace files

The container runs as UID `1000`. Files created on the host with a different UID may cause permission issues. Clone repos inside the container workspace rather than bind-mounting host directories with mismatched permissions.

### Out of disk space

Playwright Chromium and Node modules can use significant disk space. Monitor your VPS disk usage and prune unused Docker images periodically:

```bash
docker system prune -a
```

*(Run on the VPS host, not inside code-server.)*

---

## Roadmap

- [ ] **V2 — Optional Docker CLI** behind a build arg (`ENABLE_DOCKER_CLI=true`) with socket mount documentation and security warnings
- [ ] **Coolify MCP integration** for agent-driven deployments
- [ ] **Devcontainer** config for identical local development outside Docker
- [ ] **Multi-arch builds** (arm64 support for ARM VPS)

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

## Contributing

Issues and pull requests are welcome. If you add extensions or tools, update `config/extensions.txt`, the Dockerfile, and this README accordingly.

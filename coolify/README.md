# Coolify deployment reference

Quick-reference for deploying **ai-codeserver-env** on [Coolify](https://coolify.io) v4+.

Tested against **Coolify v4.3.14**.

Full guide: [main README](../README.md#deploying-on-coolify).

## Repository

```
https://github.com/lugapi/ai-codeserver-env
```

## Recommended: Docker Compose build pack

| Coolify field | Value |
|---------------|-------|
| Resource type | **Application** → Public Repository |
| Build Pack | `Docker Compose` |
| Base Directory | `/` |
| Docker Compose Location | `/docker-compose.yaml` |
| Domains | `https://code.yourdomain.com` |

### Auto-configured from docker-compose.yaml

| What | How |
|------|-----|
| Password | Magic var `SERVICE_PASSWORD_CODESERVER` → `PASSWORD` |
| Volumes | `code-server-data`, `code-server-config`, `workspace`, `coder-ssh` |
| Port | `expose: 8080` (Traefik proxy) |
| Health check | `GET /healthz` on port 8080 |

No manual Persistent Storage or `openssl rand` needed.

### Retrieve the password after deploy

**Configuration** → **Environment Variables** → `SERVICE_PASSWORD_CODESERVER`

## Alternative: Dockerfile build pack

| Coolify field | Value |
|---------------|-------|
| Build Pack | `Dockerfile` |
| Dockerfile Location | `/Dockerfile` |
| Ports Exposes | `8080` |

Then manually set `PASSWORD` and add 3 persistent volume mounts. See [README](../README.md#alternative-dockerfile-build-pack).

## Local development (not Coolify)

```bash
cp .env.example .env
docker compose -f docker-compose.yaml -f docker-compose.local.yml up -d --build
```

## Official Coolify docs

- [Docker Compose build pack](https://coolify.io/docs/applications/build-packs/docker-compose)
- [Magic environment variables](https://coolify.io/docs/knowledge-base/docker/compose#coolifys-magic-environment-variables)
- [Public GitHub repository](https://coolify.io/docs/applications/ci-cd/github/public-repository)

## GitHub SSH (from code-server)

| Action | URL |
|--------|-----|
| Add deploy key (one repo) | `https://github.com/lugapi/YOUR_REPO/settings/keys` |
| Add account SSH key | [github.com/settings/ssh/new](https://github.com/settings/ssh/new) |
| Revoke account SSH keys | [github.com/settings/keys](https://github.com/settings/keys) |

Full setup guide: [README → Connect GitHub with SSH](../README.md#connect-github-with-ssh-recommended)

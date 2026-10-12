# Nginx + Docker + GitHub Actions CI/CD

A minimal, complete DevOps exercise: static web page served by Nginx in Docker; build and deployment scripts; GitHub Actions builds and tests the Docker image on every push to `main` and on pull requests. Remote deployment is optional and only enabled once the receiving company configures its own server.

## Structure

```text
site/index.html                 Demo web page
nginx.conf                      Nginx config and /health endpoint
Dockerfile                      Docker image with healthcheck
.dockerignore                   Docker build exclusions
scripts/build-and-deploy.sh     Local build + deploy
scripts/deploy.sh               Pull + deploy + check + rollback on failure
.github/workflows/deploy.yml    CI/CD pipeline
```

## 1. Test locally

Prerequisites: Docker Engine (or Docker Desktop), Bash, curl.

```bash
bash scripts/build-and-deploy.sh
curl -i http://localhost:8080/health
```

Open **http://localhost:8080**. To change the port:

```bash
PORT=8090 bash scripts/build-and-deploy.sh
```

Do not change the port of an existing deployment without freeing the old port and checking your firewall/reverse-proxy setup.

## 2. Prepare Ubuntu test server (only for the company performing deployment)

Install Docker Engine following official Docker documentation. Make sure it works:

```bash
docker --version
sudo systemctl enable --now docker
```

Create a deployment account with Docker permission, or ensure the selected SSH user can run `docker` without interactive sudo. **Warning:** membership in the `docker` group is effectively root-level access; use a dedicated trusted deployment account and restrict SSH access.

```bash
sudo usermod -aG docker <deploy_user>
# Log out and back in for group membership to take effect.
```

Install curl (`sudo apt-get install -y curl`). Allow SSH port 22, and app port **8080** in the firewall/security group. For a real deployment, prefer a domain with HTTPS via a reverse proxy in front of port 8080 rather than exposing plain HTTP.

Set up an SSH key pair and authorize its **public key** in the account's `~/.ssh/authorized_keys`. Verify login from your own machine.

## 3. Push to GitHub

Create a GitHub repository, commit all files and push branch `main`:

```bash
git init
git add .
git commit -m "Initial Docker Nginx CI/CD"
git branch -M main
git remote add origin git@github.com:OWNER/REPO.git
git push -u origin main
```

GitHub Actions → repository **Settings → Secrets and variables → Actions**:

**Repository secrets**:

| Name | Meaning |
| --- | --- |
| `SERVER_HOST` | Server IP or domain |
| `SERVER_USER` | SSH deployment username |
| `SERVER_SSH_KEY` | Private SSH key for server login (entire content) |
| `SERVER_SSH_KNOWN_HOSTS` | Verified SSH host key line for the host (see below) |
| `GHCR_USER` | GitHub username with read access to this image |
| `GHCR_READ_TOKEN` | GitHub classic PAT with `read:packages` permission |

**Repository variables:**

- `ENABLE_DEPLOY`: set to `true` to activate publishing to GHCR and SSH deployment. Leave unset (the default) to run CI only, without requiring any server or credentials.
- `APP_PORT`: optional; default `8080`.

Obtain `SERVER_SSH_KNOWN_HOSTS` with `ssh-keyscan -H your-server` **and compare the fingerprint against the server’s fingerprint through a trusted channel** before saving it. Do not blindly trust the output of `ssh-keyscan`.

The GHCR package may be private, so use `GHCR_USER` and `GHCR_READ_TOKEN` to authenticate pulls on the test server. Set package access rights so the CI workflow can publish to GHCR (repository Actions: read/write packages permissions). If a PAT uses organization SSO, authorize it for the organization.

**Security:** Never commit private SSH keys, tokens, passwords, or `.env` secrets.

## 4. What happens on every commit to `main`

1. GitHub Actions builds a Docker image, runs it on the GitHub-hosted runner, and checks `/` and `/health`. This CI job needs **no VPS, public URL, SSH credentials, or paid hosting**.
2. If and only if repository variable `ENABLE_DEPLOY=true`, the second job builds and pushes a commit-tagged image to GitHub Container Registry.
3. That deployment job connects to the company's Ubuntu VPS through SSH, copies `deploy.sh`, pulls the image, replaces the running container, and performs an HTTP healthcheck.
4. The deployment script attempts to restore the previous container if the new image fails verification.

Then open `http://SERVER_IP:8080/` (assuming firewall allows access).

**Note:** This sample deployment stops the old container before starting the new one, so there is brief downtime even when deploy succeeds. For zero-downtime deployment, use a reverse proxy/load balancer with blue/green slots and health-aware switch-over.

## 5. Verify, troubleshoot, remove

On the server:

```bash
docker ps
docker logs nginx-cicd-demo
docker inspect --format '{{json .State.Health}}' nginx-cicd-demo
curl -i http://127.0.0.1:8080/health
```

If the build fails, review the **Actions** tab; if SSH fails, verify host key, user, firewall, and SSH private key; if GHCR pull fails, review image package access and read token. If port 8080 is busy, choose an unused `APP_PORT` and redeploy.

To remove the container:

```bash
docker rm -f nginx-cicd-demo
```

## Optional improvements

- HTTPS and DNS via Nginx reverse proxy + Let's Encrypt.
- Prometheus/Grafana for monitoring and Loki for log collection.
- Terraform to provision compute/networking.
- Kubernetes for orchestration (unnecessary for this one-container demo).

## Evaluation checklist

- [x] Working Nginx Dockerfile
- [x] Build and deployment scripts
- [x] CI builds and tests HTTP endpoint on every push to `main` and pull request
- [x] Server deployment only runs when `ENABLE_DEPLOY=true`
- [x] Image publishing and SSH deployment configured as an optional job (requires company server and secrets)
- [x] Health checks and rollback attempt on failure
- [x] README with step-by-step setup
- [ ] External test-server deployment (to be performed by the receiving company)

## Handoff to evaluator (no personal VPS required)

The project is intentionally **infrastructure-portable**. The author delivers source code and GitHub Actions CI evidence, not a hosted URL. The evaluator can run `bash scripts/build-and-deploy.sh` on a Linux host with Docker for an immediate local test, or configure the repository secrets and `ENABLE_DEPLOY=true` to perform automatic remote deployments to its own test VPS. The web UI is served at `http://SERVER_IP:8080/` once the server firewall allows the port. No server access, personal credentials, or billing information is included in this repository.

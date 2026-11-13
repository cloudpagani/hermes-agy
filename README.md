# hermes-agy

Run [Nous Research Hermes Agent](https://github.com/NousResearch/hermes-agent) inside a Docker Sandbox (`sbx`) powered by **Google Antigravity CLI (`agy`)** over native **ACP (Agent Client Protocol)** using your personal Google/Gmail subscription (OAuth).

---

## Quick Start (Using Existing Local Template)

If `docker.io/library/hermes-agy:v1` is already saved in your local `sbx` template store:

```bash
# 1. Spin up a new sandbox mounted to ./workspace
sbx create --name my-hermes --pull never -t docker.io/library/hermes-agy:v1 shell ./workspace

# 2. Run a one-shot prompt
sbx exec my-hermes -- hermes --cli -z "Hello from Hermes + Antigravity!"

# 3. Or attach interactively
sbx run --name my-hermes
# Inside the sandbox:
hermes --cli
```

Or declaratively via [sbxenv.yaml](sbxenv.yaml):

```bash
sbx env run
```

---

## Rebuilding the `hermes-agy:v1` Template From Scratch

On a fresh machine (requires Docker Desktop / `sbx`):

```bash
# 1. Run the bootstrap script to provision the base container + ACP plugin
sh ./bootstrap.sh

# 2. Complete the 1-time Google OAuth login inside the builder container
sbx run --name hermes-agy-builder
# Inside the container, run `agy`, open the OAuth URL, sign in, then exit (`Ctrl+D Ctrl+D`).

# 3. Fix token permissions and snapshot the reusable template
sbx exec hermes-agy-builder -- sh -c 'chmod -R 777 /root/.gemini && hermes gateway stop --yes 2>/dev/null || true'
sbx stop hermes-agy-builder
sbx template save hermes-agy-builder hermes-agy:v1
```

---

## Deploying to Docker Cloud Sandboxes (`sbx --cloud`)

Because `agy` and your Linux OAuth refresh token live inside the container rootfs, you can move a sandbox or upload the template directly to Docker Cloud (bypassing the 276MB OCI mixin limit):

```bash
# Move a local sandbox directly to the cloud
sbx move my-hermes --to-cloud --name my-hermes-cloud

# Or export and upload as a reusable cloud template
sbx template save my-hermes hermes-agy:v1 --output /tmp/hermes-agy.tar
sbx --cloud template load /tmp/hermes-agy.tar hermes-agy-cloud --cpus 2 --memory-mib 4096
```

---

## Architecture

```
Hermes Agent (UID 10000)
  └── Built-in ACPClient (/opt/hermes/plugins/model-providers/agy)
        └── Spawns `/usr/local/bin/agy acp` (stdio JSON-RPC)
              └── Authenticates via `/root/.gemini/antigravity-cli/antigravity-oauth-token`
```

- **Zero API Keys**: Uses native Google/Gmail OAuth inside the Linux container.
- **Zero Custom Bridges**: Uses Hermes's built-in `ACPClient` talking directly to `agy acp`.
- **Zero-Touch Replication**: `/opt/hermes/bin/hermes` auto-seeds `/opt/data/config.yaml` and symlinks `/opt/data/.gemini` on first boot whenever a new container is created from `hermes-agy:v1`.

## Repository Layout

- [sbxenv.yaml](sbxenv.yaml) — Declarative `sbx env` configuration using `docker.io/library/hermes-agy:v1`.
- [bootstrap.sh](bootstrap.sh) — Reproducible script to build `hermes-agy:v1` from `nousresearch/hermes-agent:latest`.
- [spec.yaml](spec.yaml) — Base sandbox spec reference.
- `workspace/` — Default bind-mounted working directory for sandbox sessions.

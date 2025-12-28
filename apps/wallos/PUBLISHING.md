Publishing Docker images to GitHub Container Registry (GHCR) 🔧

This repository includes a GitHub Actions workflow at `.github/workflows/docker-publish.yml` that builds and publishes the `wallos` Docker image to GHCR.

What the workflow does ✅

- Runs on push to `main` and on tag pushes (`v*`).
- Builds multi-architecture images (linux/amd64, linux/arm64).
- Tags images as:
  - `ghcr.io/<OWNER>/wallos:latest`
  - `ghcr.io/<OWNER>/wallos:<short-sha>`
  - When you push a Git tag (e.g. `v4.6.0`) the workflow will also push `ghcr.io/<OWNER>/wallos:v4.6.0`.
- Adds basic OCI labels (source, revision, created date).

Setup notes ⚠️

- The workflow uses the automatically provided `GITHUB_TOKEN` to authenticate and requires `packages: write` permission. The workflow file already sets this permission.
- No additional secrets are required for a normal push from the same repo. If you want to push from a fork or external automation, create a Personal Access Token (PAT) with `write:packages` and store it in `Secrets` (e.g. `GHCR_PAT`) and update the workflow to use that secret.

How to pull the image

- Latest: docker pull ghcr.io/<OWNER>/wallos:latest
- By sha: docker pull ghcr.io/<OWNER>/wallos:<sha>
- By release tag: docker pull ghcr.io/<OWNER>/wallos:vX.Y.Z

Tips 💡

- Make the package public or configure package permissions in GitHub so other users or automation can pull it.
- If you need more tags/labels or additional build args, update `.github/workflows/docker-publish.yml`.

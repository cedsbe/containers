# actions-runner

A custom container image built on top of the upstream [actions/runner](https://github.com/actions/runner) image, with additional dependencies and tools baked in.

## Purpose

This image is used as the runner image for self-hosted runners managed by [Actions Runner Controller (ARC)](https://docs.github.com/en/actions/tutorials/use-actions-runner-controller/get-started) on Kubernetes.

The upstream `actions/runner` image only ships the bare runner binary. Workflows typically need additional CLI tools (e.g. Docker, kubectl, git, language runtimes) to be available on the runner itself. Rather than installing these tools as a step in every workflow, this image extends the base runner image and bundles those dependencies, so they are available to all jobs scheduled on these runners.

## Customizations

The additional tooling installed on top of the base runner image is based on the [`ubuntu-slim` image from `actions/runner-images`](https://github.com/actions/runner-images/blob/main/images/ubuntu-slim/Dockerfile), which is the same image GitHub uses for its hosted runners. This keeps the self-hosted runner environment close to what workflows would get on a GitHub-hosted runner.

## Usage

Build the image and reference it as the `image` for the runner container in your ARC `RunnerDeployment` / `RunnerScaleSet` configuration.

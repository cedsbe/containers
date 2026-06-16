FROM ghcr.io/actions/actions-runner:latest@sha256:08c30b0a7105f64bddfc485d2487a22aa03932a791402393352fdf674bda2c29

ARG IMAGE_VERSION=1.0.0
ARG IMAGE_OWNER="GitHub"

USER root

ENV IMAGE_OWNER=$IMAGE_OWNER
ENV ImageVersion=$IMAGE_VERSION
ENV IMAGE_VERSION=$IMAGE_VERSION
ENV ImageOS="Linux"
ENV IMAGE_TARGET_PLATFORM="GitHub"
ENV POWERSHELL_DISTRIBUTION_CHANNEL="GitHub-Actions-$ImageOS"
ENV IMAGEDATA_NAME="ubuntu:24.04"
ENV NVM_DIR="/etc/skel/.nvm"
ENV HELPER_SCRIPTS="/tmp/scripts/helpers"
ENV INSTALLER_SCRIPT_FOLDER="/tmp/toolsets"
ENV INSTALLER_CUSTOM_SCRIPT_FOLDER="/tmp/custom-toolsets"

COPY scripts/build /tmp/scripts/build
COPY scripts/helpers /tmp/scripts/helpers
COPY toolsets/ /tmp/toolsets/
RUN find /tmp/scripts -name "*.sh" -type f -exec chmod +x {} \;

COPY custom/build/ /tmp/custom/build/
COPY custom/toolsets/ /tmp/custom-toolsets/
RUN find /tmp/custom/build -name "*.sh" -type f -exec chmod +x {} \;

COPY scripts/entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

RUN echo 'set -eo pipefail' >> /etc/bash.bashrc

RUN apt-get update && apt-get upgrade -y && apt-get install -y sudo lsb-release jq dpkg && \
  echo "root ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN touch /run/.containerenv && \
  /tmp/scripts/build/configure-apt-sources.sh && \
  /tmp/scripts/build/configure-apt.sh && \
  /tmp/scripts/build/install-apt-vital.sh && \
  /tmp/scripts/build/install-ms-repos.sh && \
  /tmp/scripts/build/configure-image-data-file.sh && \
  /tmp/scripts/build/configure-environment.sh && \
  /tmp/scripts/build/install-actions-cache.sh && \
  /tmp/scripts/build/install-apt-common.sh && \
  /tmp/scripts/build/install-azcopy.sh && \
  /tmp/scripts/build/install-azure-cli.sh && \
  /tmp/scripts/build/install-azure-devops-cli.sh && \
  /tmp/scripts/build/install-git.sh && \
  /tmp/scripts/build/install-git-lfs.sh && \
  /tmp/scripts/build/install-github-cli.sh && \
  /tmp/scripts/build/install-nvm.sh && \
  /tmp/scripts/build/install-nodejs.sh && \
  /tmp/scripts/build/install-powershell.sh && \
  /tmp/scripts/build/configure-dpkg.sh && \
  /tmp/scripts/build/install-yq.sh && \
  /tmp/scripts/build/install-python.sh && \
  /tmp/scripts/build/install-zstd.sh && \
  /tmp/scripts/build/install-pipx-packages.sh && \
  /tmp/scripts/build/install-docker-cli.sh && \
  echo "----------------------------------" && \
  /tmp/custom/build/install-apt-custom.sh && \
  /tmp/custom/build/install-terraform.sh && \
  echo "----------------------------------" && \
  /tmp/scripts/build/configure-system.sh && \
  /tmp/scripts/helpers/cleanup.sh

RUN sed -i '/set -eo pipefail/d' /etc/bash.bashrc

USER runner

ENTRYPOINT ["/opt/entrypoint.sh"]

CMD [ "bash" ]

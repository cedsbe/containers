#!/bin/bash -e
################################################################################
##  File:  install-azcopy.sh
##  Desc:  Install AzCopy
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

# Install AzCopy10
dpkg_arch=$(dpkg --print-architecture)
if [ "$dpkg_arch" = "amd64" ]; then
  azcopy_url="https://aka.ms/downloadazcopy-v10-linux"
elif [ "$dpkg_arch" = "arm64" ]; then
  azcopy_url="https://aka.ms/downloadazcopy-v10-linux-arm64"
else
  echo "Unsupported architecture for azcopy: $dpkg_arch"; exit 1
fi
archive_path=$(download_with_retry "$azcopy_url")
tar xzf "$archive_path" --strip-components=1 -C /tmp
install /tmp/azcopy /usr/local/bin/azcopy

# Create azcopy 10 alias for backward compatibility
ln -sf /usr/local/bin/azcopy /usr/local/bin/azcopy10

#!/bin/bash -e
################################################################################
##  File:  install-powershell.sh
##  Desc:  Install PowerShell Core
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh
source $HELPER_SCRIPTS/os.sh

pwsh_version=$(get_toolset_value .pwsh.version)

# Custom installation of PowerShell for arm64 architecture, since Microsoft does not provide a deb package for it.
# For amd64, we can use the deb package.

dpkg_arch=$(dpkg --print-architecture)

if [ "$dpkg_arch" = "amd64" ]; then
    apt-get install powershell=$pwsh_version*
elif [ "$dpkg_arch" = "arm64" ]; then
    pwsh_archive_url=$(resolve_github_release_asset_url "PowerShell/PowerShell" 'endswith("linux-arm64.tar.gz")' "${pwsh_version}" "false" "true")
    archive_path=$(download_with_retry "$pwsh_archive_url")
    mkdir -p /opt/microsoft/powershell/7
    tar xzf "$archive_path" -C /opt/microsoft/powershell/7
    chmod +x /opt/microsoft/powershell/7/pwsh
    ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh
else
    echo "Unsupported architecture for powershell: $dpkg_arch"; exit 1
fi

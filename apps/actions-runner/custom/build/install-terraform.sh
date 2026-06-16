#!/bin/bash -e
################################################################################
##  File:  install-terraform.sh
##  Desc:  Install terraform
##  Source:  https://github.com/actions/runner-images/blob/main/images/ubuntu/scripts/build/install-terraform.sh
################################################################################

source $HELPER_SCRIPTS/install.sh
source $HELPER_SCRIPTS/os.sh

terraform_arch="amd64"

# Install Terraform
download_url=$(curl -fsSL https://api.releases.hashicorp.com/v1/releases/terraform/latest | jq -r ".builds[] | select((.arch==\"$terraform_arch\") and (.os==\"linux\")).url")
archive_path=$(download_with_retry "${download_url}")
unzip -qq "$archive_path" -d /usr/local/bin

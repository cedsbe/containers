#!/bin/bash -e
################################################################################
##  File:  install-apt-custom.sh
##  Desc:  Install custom command line utilities and dev packages
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/install.sh

custom_packages=$(
  INSTALLER_SCRIPT_FOLDER="$INSTALLER_CUSTOM_SCRIPT_FOLDER"
  get_toolset_value .apt.custom_packages[]
)

apt-get install --no-install-recommends $custom_packages

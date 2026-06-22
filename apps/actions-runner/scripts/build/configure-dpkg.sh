#!/bin/bash -e
################################################################################
##  File:  configure-dpkg.sh
##  Desc:  Configure dpkg
################################################################################

# Source the helpers for use with the script
source $HELPER_SCRIPTS/etc-environment.sh
source $HELPER_SCRIPTS/os.sh
# This is the anti-frontend. It never interacts with you  at  all,
# and  makes  the  default  answers  be used for all questions. It
# might mail error messages to root, but that's it;  otherwise  it
# is  completely  silent  and  unobtrusive, a perfect frontend for
# automatic installs. If you are using this front-end, and require
# non-default  answers  to questions, you will need to pre-seed the
# debconf database
set_etc_environment_variable "DEBIAN_FRONTEND" "noninteractive"

# dpkg can be instructed not to ask for confirmation
# when replacing a configuration file (with the --force-confdef --force-confold options)
cat <<EOF >> /etc/apt/apt.conf.d/10dpkg-options
Dpkg::Options {
  "--force-confdef";
  "--force-confold";
}
EOF

# hide information about packages that are no longer required
cat <<EOF >> /etc/apt/apt.conf.d/10apt-autoremove
APT::Get::AutomaticRemove "0";
APT::Get::HideAutoRemove "1";
EOF

# Install libicu70 package for Ubuntu 24
if is_ubuntu24; then
  dpkg_arch=$(dpkg --print-architecture)
  if [ "$dpkg_arch" = "amd64" ]; then
    icu_url="https://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu70_70.1-2_amd64.deb"
    icu_expected_sha512="a6315482d93606e375c272718d2458870b95e4ed4b672ea8640cf7bc2d2c2f41aea13b798b1e417e1ffc472a90c6aad150d3d293aa9bddec48e39106e4042807"
  elif [ "$dpkg_arch" = "arm64" ]; then
    icu_url="https://ports.ubuntu.com/ubuntu-ports/pool/main/i/icu/libicu70_70.1-2_arm64.deb"
    icu_expected_sha512="14ebf6ca091cdbda96aa15821eb02a72dc2156d5bcfa820e7cb9dad5e528f31452d9bdbd806c0cbd49b4d3a4d8dedc28ae52053727810e0ad74fd31bcf9b623c"
  else
    echo "Unsupported architecture for libicu70: $dpkg_arch"; exit 1
  fi
  icu_deb="libicu70_70.1-2_${dpkg_arch}.deb"
  wget "$icu_url" -O "$icu_deb"
  ACTUAL_LIBICU_SHA512="$(sha512sum "./${icu_deb}" | awk '{print $1}')"
  [ "$icu_expected_sha512" = "$ACTUAL_LIBICU_SHA512" ] || { echo "libicu checksum mismatch in configure-dpkg.sh"; exit 1; }
  sudo apt-get install -y "./${icu_deb}"
fi

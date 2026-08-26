#!/usr/bin/env bash
# Install apt packages (no recommends) and purge the apt caches.
# Usage: apt-install.sh <package>...
set -euo pipefail

# shellcheck source=scripts/lib/common.sh
. "${BASH_SOURCE[0]%/*}/lib/common.sh"

[ "$#" -gt 0 ] || { echo "usage: ${0##*/} <package>..." >&2; exit 1; }

apt_install "$@"

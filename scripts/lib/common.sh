# shellcheck shell=bash
# Helpers shared by the build-time install scripts.  Sourced, never executed;
# callers keep their own `set -euo pipefail`.

# Fail unless every named variable is set and non-empty.
require_env() {
    local var
    for var in "$@"; do
        if [ -z "${!var:-}" ]; then
            echo "$(basename "${0}"): $var is required" >&2
            exit 1
        fi
    done
}

# Drop the apt metadata and package caches — build-time junk in every stage.
apt_clean() {
    rm -rf /var/cache/apt/archives/* /var/lib/apt/lists/*
}

# apt-get install without recommends, then clean up after ourselves.
apt_install() {
    apt-get update
    apt-get install -yq --no-install-recommends "$@"
    apt_clean
}

# Download a single release binary and make it executable.
fetch_bin() {
    local url=$1 dest=$2
    curl -fsSL "$url" -o "$dest"
    chmod +x "$dest"
}

# Delete a file along with every other hardlink to it under $1.  Store payloads
# are hardlinked, so bytes are only freed once the last link is gone.
unlink_hardlinks() {
    local root=$1 file=$2
    find "$root" -samefile "$file" ! -path "$file" -delete 2>/dev/null || true
    rm -f "$file"
}

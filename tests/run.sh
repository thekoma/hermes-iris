#!/bin/bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
status=0

for test_file in "$ROOT"/tests/*-test.bash; do
    printf '\n# %s\n' "${test_file##*/}"
    /bin/bash "$test_file" || status=1
done

exit "$status"

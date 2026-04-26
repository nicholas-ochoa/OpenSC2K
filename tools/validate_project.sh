#!/bin/sh
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec python3 "$repo_dir/tools/validate_project.py" "$@"

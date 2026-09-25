#!/bin/bash
# Install the pinned official engine and desktop templates on a macOS runner.
set -euo pipefail
version=4.7.2
base="https://github.com/godotengine/godot/releases/download/${version}-stable"
staging="${RUNNER_TEMP:?}/godot-${version}"
mkdir -p "$staging/bin"
curl --fail --location --retry 3 "$base/Godot_v${version}-stable_macos.universal.zip" -o "$staging/engine.zip"
curl --fail --location --retry 3 "$base/Godot_v${version}-stable_export_templates.tpz" -o "$staging/templates.tpz"
(
  cd "$staging"
  shasum -a 256 --check <<'SUMS'
c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e  engine.zip
f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011  templates.tpz
SUMS
)
ditto -x -k "$staging/engine.zip" "$staging"
ln -s "$staging/Godot.app/Contents/MacOS/Godot" "$staging/bin/godot"
templates="$HOME/Library/Application Support/Godot/export_templates/${version}.stable"
mkdir -p "$templates"
unzip -j -o "$staging/templates.tpz" 'templates/macos.zip' \
  'templates/linux_release.x86_64' 'templates/windows_release_x86_64.exe' \
  'templates/version.txt' -d "$templates"
echo "$staging/bin" >> "${GITHUB_PATH:?}"
"$staging/bin/godot" --version

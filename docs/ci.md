# CI and nightly builds

The **CI and nightly** GitHub Actions workflow runs on pull requests and pushes to `main`.
It tests the project and builds Windows x64, Linux x64, and universal macOS packages.
Packages are available as the `desktop-packages` workflow artifact for one day.
Test logs are retained for seven days.

## Nightly releases

The workflow runs daily at **08:23 UTC** (03:23 CDT or 02:23 CST).
GitHub can delay scheduled runs. Inactive public repositories can have schedules disabled after 60 days.

After all checks and exports pass, the workflow publishes a nightly prerelease.
It verifies the uploaded hashes before publication. It then deletes older nightlies from this workflow,
including their tags and release assets. It keeps the previous successful nightly if a build or upload fails.
Stable releases, including `v0.1.0`, are not changed. A nightly does not replace the latest stable release.

To run it manually, select **Actions > CI and nightly > Run workflow** on `main`.
Select **Publish a nightly and remove previous nightly releases** to publish the result.
Leave it clear to run tests and build packages only.
No repository secrets are required. Only the publication job has permission to write releases.

## Test coverage

`tools/validate_project.sh --suite ci` runs product tests with generated data.
It also checks editor parsing and startup. It uses Dummy audio and rejects errors and skips.
Pillow and FFmpeg are required for the selected image and audio tests.
Tests that require original game files, imported packs, large-city fixtures, or native windows are not selected.
The CI selection uses the test registry, so new product tests without those requirements are included automatically.

CI does not replace `--suite release`. Run the full release suite locally before a stable release.
GitHub-hosted runners do not have the original SimCity 2000 files. Their package builds do not prove
Windows or Linux gameplay, native GPU rendering, or original-game compatibility.

## Build tools

`tools/setup_godot_ci.sh` installs Godot 4.7.2 and its desktop export templates on a macOS runner.
Both downloads are checked against pinned SHA-256 hashes from the official Godot release.
Update the version and hashes together when upgrading the engine.

To build locally on macOS after validation:

```sh
python3 tools/build_desktop_release.py --output local/packages --label 0.1.0
```

Use a new output directory. The tool exports the committed tree at `HEAD`.
It includes install notes, licenses, source and engine versions, and package hashes.
The macOS app is ad-hoc signed and is not notarized. Windows packages are unsigned.

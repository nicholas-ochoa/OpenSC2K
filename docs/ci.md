# CI and nightly builds

The **CI and nightly** GitHub Actions workflow runs on pull requests and pushes to `main`.
It tests the project and builds Windows x64, Linux x64, and universal macOS packages.
Packages are available as the `desktop-packages` workflow artifact for one day.
Generated-data test logs are retained for seven days.
Private asset tests run in a separate job and upload no artifacts.

## Pull-request approval

GitHub requires approval for workflows from all external contributors.
The CI build job also uses the `pull-request-ci` environment for pull requests.
That environment requires approval from `nicholas-ochoa` before any build steps run,
including for same-repository pull requests. Private assets are never supplied to PR jobs.

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
The private test job uses the `TEST_ASSETS_SSH_KEY` environment secret.
Only the publication job has permission to write releases.

## Test coverage

`tools/validate_project.sh --suite ci` runs product tests with generated data.
It also checks editor parsing and startup. It uses Dummy audio and rejects errors and skips.
Pillow and FFmpeg are required for the selected image and audio tests.
Tests that require original game files, imported packs, or native windows are not selected.
The CI selection uses the test registry, so new product tests without those requirements are included automatically.

CI does not replace `--suite release`. Run the full release suite locally before a stable release.
Package builds do not prove Windows or Linux gameplay, native GPU rendering, or
original-game compatibility.

## Private asset coverage

Trusted `main` pushes, nightly runs, and manual runs also test a pinned commit from
the private `nicholas-ochoa/OpenSC2K-Test-Assets` repository. Its `references/` and
`ext/` folders are available only in the separate private test job. The read-only
deploy key is an environment secret in `private-test-assets`, which permits only
the `main` branch. The job does not run for pull requests.

`tools/run_private_asset_checks.py` selects the headless `full` checks that the
generated-data `ci` suite does not cover. Missing inputs, skipped checks, and
test errors fail the job. It uses Dummy audio. Native checks remain local.

Full test output, warnings, and failure details appear in the GitHub Actions log.
The job uploads no artifacts and saves no caches. Inputs and generated files are
removed at the end. Package builds run on a separate runner without these assets.
Nightly publication requires both test jobs to pass.

To update the inputs, commit and push them in the private repository, then update
the pinned asset commit in `.github/workflows/ci.yml`. To diagnose a failed check,
read the Actions log or run its test ID locally with the private inputs. Do not upload
screenshots, saves, extracted packs, or other files produced from the original assets.

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

## Manual stable releases

Open **Actions > Release > Run workflow** and select `main`.
The version input label shows the last published stable version, for example
**Version to release (last published: 0.1.0)**. The workflow also fetches the current value for its run summary.
Nightly prereleases and drafts do not count as published stable versions.
After publication, the workflow commits the new version into its input label for the next run.
Publishing a draft through GitHub also updates this label. Failed builds and unpublished drafts leave it unchanged.

To create a release, enter a new version such as `0.1.1` and run the workflow.
The workflow commits the project version to `main`, runs CI on that exact commit, builds the three
platform packages, verifies their uploaded hashes, and publishes `v0.1.1` as the latest stable release.
Select **draft** to leave the release unpublished for review instead.
The version is set inside the application, in the package names, and in the build information.
Stable release notes include a collapsed list of commit messages and links since the last published
stable release, through the exact build commit. The first stable release includes all prior commits.
Nightly builds do not include this list.

Existing releases and tags are not overwritten. The new version must exceed all published stable versions.
The workflow keeps all prior stable releases. It does not perform nightly cleanup.
The version commit remains on `main` if testing or building fails; rerun with the same version after resolving
the failure. If publication leaves a draft, inspect or remove that draft before retrying the same version.
A concurrent change to `main` can reject the version push; rerun against the updated branch.
The repository must allow the workflow token to push the version commit to `main`.
The label update uses the `RELEASE_SSH_KEY` secret, which must contain a write-enabled repository deploy key.
This lets the job push the workflow file. Its commit uses `[skip ci]` to avoid another CI build.
If this update fails after publication, the release remains published. Rerun the failed job to update the label.

Run the full local release suite before publishing a stable release. The stable-release workflow
uses the generated-data suite. The separate private asset job belongs to CI and nightly builds;
it does not replace the local native checks required for a stable release.

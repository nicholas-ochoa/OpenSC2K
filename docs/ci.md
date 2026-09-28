# CI and nightly builds

The **CI and nightly** GitHub Actions workflow runs on pull requests and pushes to `main`.
It has two jobs:

- **Test** runs `tools/validate_project.sh --strict --keep-going` with the original-game assets.
  This is the same `headless` suite that you run locally before merge.
- **Build** makes Windows x64, Linux x64, and universal macOS packages on a separate runner
  without the assets. Packages are available as the `desktop-packages` workflow artifact for one day.

`.github/workflows/test.yml` defines the Test job. The CI and Release workflows both use it.

## Tests

The Test job checks out a pinned commit from the private `nicholas-ochoa/OpenSC2K-Test-Assets`
repository and links its `references/` and `ext/` folders into the checkout. `--strict` makes
missing inputs and skipped checks fail the job. It uses Dummy audio.

The job uploads no artifacts and saves no caches. Full test output appears in the Actions log.
Inputs and generated files are removed at the end. Do not upload screenshots, saves, extracted
packs, or other files produced from the original assets.

To update the inputs, commit and push them in the private repository, then update the pinned
asset commit in `.github/workflows/test.yml`. To diagnose a failed check, read the Actions log
or run its test ID locally with `--test <id>`.

CI does not run the `renderer` suite, because native tests need a real GPU window. Run
`tools/validate_project.sh --suite release` locally before a stable release. Package builds do not
prove Windows or Linux gameplay, native GPU rendering, or original-game compatibility.

`tools/validate_project.sh --suite renderer` runs all selected native tests in one
Godot process with Dummy audio. It opens one window with keyboard focus disabled.
Test dialogs stay inside that window. This also applies with `--jobs 1` and when
native tests run alongside headless tests. Each test keeps its own result, timeout,
and optional log. Scenes, preferences, and UI state are reset between tests.
A script error, crash, or timeout stops the batch and marks unfinished tests as failures.
Use `--test <id>` to rerun a single test. Native test scripts use the `scene-batch`
driver in `tools/validation_tests.json`; run them through the validation command.

## Pull requests and secrets

Pull requests from branches in this repository run both jobs. Fork pull requests run only the
Build job and never receive the assets. GitHub also requires approval for workflows from all
external contributors.

Pull-request jobs use the `pull-request-ci` environment. It requires approval from
`nicholas-ochoa` before any step runs. Review the pull request before you approve it, because
the Test job gives its code the assets. Other runs use the `private-test-assets` environment,
which permits only the `main` branch. Both environments hold the read-only deploy key as the
`TEST_ASSETS_SSH_KEY` secret.

## Nightly releases

The workflow runs daily at **08:23 UTC** (03:23 CDT or 02:23 CST).
GitHub can delay scheduled runs. Inactive public repositories can have schedules disabled after 60 days.

After both jobs pass, the workflow publishes a nightly prerelease.
It verifies the uploaded hashes before publication. It then deletes older nightlies from this workflow,
including their tags and release assets. It keeps the previous successful nightly if a build or upload fails.
Stable releases, including `v0.1.0`, are not changed. A nightly does not replace the latest stable release.

To run it manually, select **Actions > CI and nightly > Run workflow** on `main`,
or run `gh workflow run ci.yml --ref main`.
Select **Publish a nightly and remove previous nightly releases** to publish the result.
Leave it clear to run tests and build packages only.
Only the publication job has permission to write releases.

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
The workflow commits the project version to `main`, runs the Test job on that exact
commit, builds the three platform packages, verifies their uploaded hashes, and publishes `v0.1.1` as the latest stable release.
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

Run the full local release suite before publishing a stable release. Publication requires the
Test and Build jobs to pass. Neither replaces the local native checks required for a stable release.

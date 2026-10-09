#!/usr/bin/env bash
# Remove the keychain and API key of tools/setup_macos_signing_ci.sh.
set -uo pipefail

security delete-keychain "$RUNNER_TEMP/opensc2k-signing.keychain-db" 2> /dev/null
rm -f "$RUNNER_TEMP/opensc2k-signing.p12" "$RUNNER_TEMP/opensc2k-notary.p8"
exit 0

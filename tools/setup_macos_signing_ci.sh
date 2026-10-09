#!/usr/bin/env bash
# Prepare Developer ID signing and notarization on a macOS runner, for
# tools/build_desktop_release.py. Reads the repository secrets from the
# environment, imports the certificate into a temporary keychain, and writes
# MACOS_SIGNING_IDENTITY and the APPLE_API_KEY_* variables to GITHUB_ENV.
#
# SIGNING=optional leaves the build ad hoc when a secret is missing;
# SIGNING=required fails. tools/cleanup_macos_signing_ci.sh removes the files.
# See docs/ci.md for the secrets.
set -euo pipefail

SECRETS=(MACOS_CERTIFICATE_P12 MACOS_CERTIFICATE_PASSWORD APPLE_API_KEY_P8 APPLE_API_KEY_ID APPLE_API_ISSUER_ID)

# The Developer ID intermediate certificate of Apple, which a .p12 export can
# leave out. Runners may not have it, and codesign needs the full chain.
INTERMEDIATE_URL=https://www.apple.com/certificateauthority/DeveloperIDG2CA.cer
INTERMEDIATE_SHA256=f16cd3c54c7f83cea4bf1a3e6a0819c8aaa8e4a1528fd144715f350643d2df3a

KEYCHAIN="$RUNNER_TEMP/opensc2k-signing.keychain-db"
CERTIFICATE="$RUNNER_TEMP/opensc2k-signing.p12"
INTERMEDIATE="$RUNNER_TEMP/opensc2k-developer-id-g2.cer"
API_KEY="$RUNNER_TEMP/opensc2k-notary.p8"

missing=()

for name in "${SECRETS[@]}"; do
  if [ -z "${!name:-}" ]; then
    missing+=("$name")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  if [ "${SIGNING:-optional}" = required ]; then
    echo "::error::Set the repository secrets ${missing[*]} to sign and notarize the macOS app. See docs/ci.md."
    exit 1
  fi

  echo "::warning::The macOS app stays ad hoc signed. Missing repository secrets: ${missing[*]}."
  exit 0
fi

password="$(uuidgen)"
security create-keychain -p "$password" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$password" "$KEYCHAIN"

printf '%s' "$MACOS_CERTIFICATE_P12" | base64 --decode > "$CERTIFICATE"
security import "$CERTIFICATE" -k "$KEYCHAIN" -f pkcs12 -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
rm -f "$CERTIFICATE"

curl -fsSL -o "$INTERMEDIATE" "$INTERMEDIATE_URL"
echo "$INTERMEDIATE_SHA256  $INTERMEDIATE" | shasum -a 256 -c -
security import "$INTERMEDIATE" -k "$KEYCHAIN"

# codesign may use the key without a prompt, and finds identities in the search list
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$KEYCHAIN" > /dev/null
# shellcheck disable=SC2046
security list-keychains -d user -s "$KEYCHAIN" $(security list-keychains -d user | tr -d '"')

identity="$(security find-identity -v -p codesigning "$KEYCHAIN" |
  sed -n 's/^ *[0-9]*) [0-9A-F]* "\(Developer ID Application: .*\)"$/\1/p' | head -n 1)"

if [ -z "$identity" ]; then
  echo "::error::MACOS_CERTIFICATE_P12 has no valid Developer ID Application identity with its private key."
  exit 1
fi

printf '%s' "$APPLE_API_KEY_P8" | base64 --decode > "$API_KEY"

{
  echo "MACOS_SIGNING_IDENTITY=$identity"
  echo "APPLE_API_KEY_PATH=$API_KEY"
  echo "APPLE_API_KEY_ID=$APPLE_API_KEY_ID"
  echo "APPLE_API_ISSUER_ID=$APPLE_API_ISSUER_ID"
} >> "$GITHUB_ENV"

echo "Signing as $identity"

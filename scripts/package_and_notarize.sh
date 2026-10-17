#!/bin/bash
#
# Copyright 2026 Aashish Patil
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

APP_NAME="WiFiSignal"
SCHEME="WiFiSignal"
CONFIGURATION="Release"
IDENTITY="Developer ID Application: Aashish PATIL (4DCC945RL8)"
KEYCHAIN_PROFILE="NOTARY_PROFILE"
DERIVED_DATA="./DerivedData"
BUILD_DIR="${DERIVED_DATA}/Build/Products/${CONFIGURATION}"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_PATH="./${APP_NAME}.dmg"
STAGING_DIR="./dist/dmg_staging"

echo "=== 1. Building ${APP_NAME} in ${CONFIGURATION} mode ==="
xcodebuild -project "${APP_NAME}.xcodeproj" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA}" \
  clean build

echo "=== 2. Code signing ${APP_NAME}.app with Hardened Runtime & Developer ID ==="
codesign --deep --force --options runtime --timestamp \
  --entitlements Resources/WiFiSignal.entitlements \
  --sign "${IDENTITY}" \
  "${APP_PATH}"

echo "=== 3. Verifying app bundle code signature ==="
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

echo "=== 4. Staging files for DMG ==="
rm -rf ./dist
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "=== 5. Creating ${DMG_PATH} ==="
rm -f "${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" \
  -srcfolder "${STAGING_DIR}" \
  -ov -format UDZO \
  "${DMG_PATH}"

echo "=== 6. Code signing ${DMG_PATH} ==="
codesign --force --timestamp \
  --sign "${IDENTITY}" \
  "${DMG_PATH}"

echo "=== 7. Submitting to Apple Notary Service ==="
xcrun notarytool submit "${DMG_PATH}" \
  --keychain-profile "${KEYCHAIN_PROFILE}" \
  --wait

echo "=== 8. Stapling notarization ticket to ${DMG_PATH} ==="
xcrun stapler staple "${DMG_PATH}"

echo "=== 9. Verifying Gatekeeper acceptance ==="
spctl -a -vv -t install "${DMG_PATH}"

echo "=== SUCCESS! ${DMG_PATH} is signed, notarized, and stapled! ==="

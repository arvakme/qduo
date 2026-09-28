#!/usr/bin/env bash
#
# FORK: build a Release QDuo.app for personal use and (optionally) install it.
#
#   scripts/build-fork.sh            # build → build/fork/QDuo.app
#   scripts/build-fork.sh --install  # …then quit the running QDuo, replace
#                                    #    /Applications/QDuo.app and relaunch
#
# Signed with the first "Apple Development" identity in the keychain (stable
# designated requirement → Accessibility survives rebuilds), else ad-hoc.
# Same bundle id as upstream, so ~/.config/qduo/config.json is shared.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | awk -F'"' '/Apple Development/ {print $2; exit}')
# The team is the certificate's OU (the "(XXXX)" in its name is NOT the team).
TEAM=""
[ -n "$IDENTITY" ] && TEAM=$(security find-certificate -c "$IDENTITY" -p 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU=\([A-Z0-9]*\).*/\1/p')
[ -n "$TEAM" ] || IDENTITY=""
if [ -n "$IDENTITY" ]; then
  SIGN=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=$IDENTITY" "DEVELOPMENT_TEAM=$TEAM")
  echo "› signing with: $IDENTITY"
else
  SIGN=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
  echo "› no Apple Development identity — signing ad-hoc"
fi

echo "› xcodegen generate…"
xcodegen generate >/dev/null

echo "› building (Release)…"
xcodebuild -project QDuo.xcodeproj -scheme QDuo -configuration Release \
  -derivedDataPath build/fork-dd -destination 'platform=macOS' \
  "${SIGN[@]}" build 2>&1 | grep -E "(error:|warning: .*PopupChrome|BUILD SUCCEEDED|BUILD FAILED)" || true

APP=build/fork-dd/Build/Products/Release/QDuo.app
[ -d "$APP" ] || { echo "build did not produce $APP" >&2; exit 1; }
rm -rf build/fork && mkdir -p build/fork && ditto "$APP" build/fork/QDuo.app
codesign --verify --deep --strict build/fork/QDuo.app && echo "› signature OK"
echo "› built build/fork/QDuo.app"

if [ "${1:-}" = "--install" ]; then
  osascript -e 'tell application id "me.xueshi.qduo" to quit' 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -xq QDuo || break; sleep 0.5; done
  rm -rf /Applications/QDuo.app
  ditto build/fork/QDuo.app /Applications/QDuo.app
  open /Applications/QDuo.app
  echo "› installed and launched /Applications/QDuo.app"
fi

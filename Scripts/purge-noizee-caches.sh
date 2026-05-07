#!/usr/bin/env bash
# Purge on-disk caches for Noizee and the legacy Kaset app (sandbox containers).
#
# Does NOT touch:
#   - Preferences (UserDefaults), Application Support, Cookies, or WebKit WebsiteData
#     inside the container → login/state is preserved unless you extend this script.
#
# Notification icon refresh:
#   macOS notification banner leading icon is resolved by `usernoted` via
#   LaunchServices + IconServices, keyed on bundle id + CFBundleVersion + code
#   signature. Stale duplicates (Trash, ~/Applications, DerivedData) keep
#   IconServices pinned to old artwork. This script unregisters every known
#   stale path, restarts the icon/notification daemons, and (with --deep)
#   wipes the IconServices cache so the next launch repopulates from the
#   current /Applications/Noizee.app bundle.
#
# Usage:
#   ./Scripts/purge-noizee-caches.sh           # standard purge
#   ./Scripts/purge-noizee-caches.sh --deep    # also wipe IconServices cache (needs sudo)
#
set -euo pipefail

LSREG=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
DEEP=0
for arg in "$@"; do
	case "$arg" in
		--deep) DEEP=1 ;;
		*) echo "Unknown arg: $arg" >&2; exit 2 ;;
	esac
done

echo "⇢ Quitting apps (ignore errors if not running)…"
osascript -e 'quit app "Noizee"' 2>/dev/null || true
osascript -e 'quit app "Kaset"' 2>/dev/null || true
sleep 1

purge_container() {
	local id="$1"
	local base="${HOME}/Library/Containers/${id}/Data/Library"
	if [[ ! -d "$base" ]]; then
		echo "⇢ Skip (no container): ${id}"
		return 0
	fi
	echo "⇢ Clearing Caches + HTTPStorages for: ${id}"
	rm -rf "${base}/Caches/"* 2>/dev/null || true
	rm -rf "${base}/HTTPStorages/"* 2>/dev/null || true
}

# Current Noizee; legacy Kaset; older sibling bundle seen on-disk.
purge_container "com.betogzo.Noizee"
purge_container "com.sertacozercan.Kaset"
purge_container "com.sertacozercan.Noizee"

SWIFTPM_KASET_MANIFEST="${HOME}/Library/Caches/org.swift.swiftpm/manifests/ManifestLoading/kaset.dia"
if [[ -f "${SWIFTPM_KASET_MANIFEST}" ]]; then
	echo "⇢ Removing SwiftPM orphan manifest cache: kaset.dia"
	rm -f "${SWIFTPM_KASET_MANIFEST}"
fi

# Unregister every stale Noizee.app path that LaunchServices has indexed.
# Trash copies, ~/Applications, and DerivedData builds all keep IconServices
# pinned to whichever path it resolved first — so they must go before we
# refresh the canonical /Applications copy.
echo "⇢ Unregistering stale Noizee.app records from LaunchServices…"
STALE_PATHS=$(
	"${LSREG}" -dump 2>/dev/null \
	| awk '
		# Capture the path on a "path:" line. Strip the trailing "(0x...)" LS id
		# token so equality checks against /Applications/Noizee.app actually hit.
		/^path:/ {
			p = $2
			for (i = 3; i < NF; i++) p = p " " $i
			sub(/ *\([^)]*\)$/, "", p)
		}
		/identifier:/ {
			gsub(/[";]/, "", $2)
			if ($2 == "com.betogzo.Noizee" && p != "" && p != "/Applications/Noizee.app") print p
			p = ""
		}
	' \
	| sort -u
)
if [[ -n "${STALE_PATHS}" ]]; then
	while IFS= read -r STALE; do
		[[ -z "${STALE}" ]] && continue
		echo "   - ${STALE}"
		"${LSREG}" -u "${STALE}" >/dev/null 2>&1 || true
	done <<< "${STALE_PATHS}"
else
	echo "   (none)"
fi

echo "⇢ Refreshing Launch Services garbage collect…"
"${LSREG}" -gc >/dev/null 2>&1 || true

# Re-register canonical bundles. Skip ~/Applications and Trash on purpose —
# those should remain unregistered if present, otherwise IconServices may
# repin to them.
for APP in "/Applications/Noizee.app"; do
	if [[ -d "${APP}" ]]; then
		echo "⇢ Re-register: ${APP}"
		"${LSREG}" -f -R "${APP}" >/dev/null 2>&1 || true
	fi
done

# Optional deep wipe of IconServices cache — needed when notification banner
# keeps showing the previous icon despite version bump + re-register.
if [[ "${DEEP}" -eq 1 ]]; then
	echo "⇢ Deep wipe: IconServices caches (sudo required)…"
	rm -rf "${HOME}/Library/Caches/com.apple.iconservices"* 2>/dev/null || true
	sudo rm -rf /Library/Caches/com.apple.iconservices.store 2>/dev/null || true
fi

echo "⇢ Recycling icon + notification daemons…"
killall iconservicesagent 2>/dev/null || true
killall iconservicesd 2>/dev/null || true
killall usernoted 2>/dev/null || true
killall NotificationCenter 2>/dev/null || true
killall Dock 2>/dev/null || true
killall cfprefsd 2>/dev/null || true

echo "Done. Next launch refills Web caches; icons/notifications usually pick up the current .app bundle."
echo "If banner glyph still stale, re-run with --deep, then trigger one fresh notification from a re-launched Noizee."

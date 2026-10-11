#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
serial="${1:?Pass the verified USB Android serial}"
case "$serial" in *:*|*._tcp) printf '%s\n' 'Use USB; this test turns off wireless networking.'; exit 1;; esac
adb="/Users/rahmaniseif/Library/Android/sdk/platform-tools/adb"
existing="$($adb -s "$serial" shell pm list packages com.seifelmoulouk.pikolumi.qa | tr -d '\r')"
if [ -n "$existing" ]; then
    printf '%s\n' 'The isolated QA package already exists; this script will not erase its data.'
    exit 1
fi
old_airplane="$($adb -s "$serial" shell settings get global airplane_mode_on | tr -d '\r')"
old_wifi="$($adb -s "$serial" shell settings get global wifi_on | tr -d '\r')"
case "$old_airplane:$old_wifi" in 0:0|0:1|1:0|1:1) ;; *) printf '%s\n' 'Unexpected network state; no settings changed.'; exit 1;; esac
restore_network() {
    if [ "$old_airplane" = 0 ]; then "$adb" -s "$serial" shell cmd connectivity airplane-mode disable; fi
    if [ "$old_wifi" = 1 ]; then "$adb" -s "$serial" shell svc wifi enable; fi
}
trap restore_network EXIT INT TERM HUP
"$adb" -s "$serial" shell cmd connectivity airplane-mode enable
"$adb" -s "$serial" shell svc wifi disable
"$adb" -s "$serial" shell cmd connectivity airplane-mode
"$adb" -s "$serial" shell settings get global wifi_on
ORG_GRADLE_PROJECT_pikolumiQa=true scripts/flutter.sh test --no-uninstall integration_test/device_smoke_test.dart -d "$serial"

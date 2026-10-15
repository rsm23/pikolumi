#!/usr/bin/env python3
"""Cold-launch the installed release on an emulator without clearing app data."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--serial', required=True)
    parser.add_argument('--adb', default=str(Path(os.environ.get(
        'ANDROID_HOME', str(Path.home() / 'Library/Android/sdk')))
        / 'platform-tools/adb'))
    parser.add_argument('--expected-page-size', type=int, choices=[4096, 16384], required=True)
    parser.add_argument('--expected-avd', required=True)
    parser.add_argument('--seconds', type=int, default=15)
    parser.add_argument('--attempts', type=int, default=3)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.serial.startswith('emulator-'):
        parser.error('Use an isolated emulator; this check resets its log buffers.')
    if args.seconds < 5 or args.attempts < 1:
        parser.error('Use at least five seconds and one attempt.')
    package = 'com.seifelmoulouk.pikolumi'
    args.output.mkdir(parents=True, exist_ok=True)

    def adb(*command):
        result = subprocess.run(
            [args.adb, '-s', args.serial, *command],
            capture_output=True, text=True, timeout=30)
        if result.returncode:
            raise RuntimeError(result.stderr or result.stdout)
        return result.stdout

    avd = adb('emu', 'avd', 'name').splitlines()[0].strip()
    page_size = int(adb('shell', 'getconf', 'PAGE_SIZE').strip())
    if avd != args.expected_avd or page_size != args.expected_page_size:
        raise RuntimeError(f'Wrong emulator: {avd}, page size {page_size}')

    runs = []
    for attempt in range(1, args.attempts + 1):
        adb('shell', 'am', 'force-stop', package)
        adb('logcat', '-c')
        launch = adb('shell', 'am', 'start', '-n', f'{package}/.MainActivity')
        time.sleep(args.seconds)
        # pidof returns 1 when the app has died, which is the failure under test.
        pid = subprocess.run(
            [args.adb, '-s', args.serial, 'shell', 'pidof', package],
            capture_output=True, text=True, timeout=10).stdout.strip()
        log = adb('logcat', '-d', '-v', 'threadtime',
                  'AndroidRuntime:E', 'flutter:E', 'libc:F', '*:S')
        activity = adb('shell', 'dumpsys', 'activity', 'activities')
        resumed = [line.strip() for line in activity.splitlines()
                   if 'ResumedActivity' in line and package in line]
        fatal = 'FATAL EXCEPTION' in log or 'Fatal signal' in log
        passed = bool(pid and resumed and not fatal and 'Error:' not in launch)
        (args.output / f'launch-{attempt}.log').write_text(launch + log)
        runs.append({'attempt': attempt, 'pid': pid, 'resumed': resumed,
                     'fatal': fatal, 'passed': passed})
        print(json.dumps(runs[-1]), flush=True)
        if not passed:
            break
    report = {'serial': args.serial, 'avd': avd, 'sdk': adb('shell', 'getprop',
              'ro.build.version.sdk').strip(), 'pageSize': adb('shell',
              'getconf', 'PAGE_SIZE').strip(), 'secondsPerLaunch': args.seconds,
              'appDataCleared': False, 'attempts': runs,
              'passed': len(runs) == args.attempts and all(r['passed'] for r in runs)}
    (args.output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    raise SystemExit(0 if report['passed'] else 1)


if __name__ == '__main__':
    main()

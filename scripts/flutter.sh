#!/bin/sh
set -eu
export PATH="$HOME/.cache/pikolumi/flutter/bin:$HOME/.gem/ruby/4.0.0/bin:/opt/homebrew/opt/ruby/bin:$PATH"
if [ -z "${JAVA_HOME:-}" ] && [ -d /opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home ]; then
  export JAVA_HOME="/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home"
fi
if [ -n "${PIKOLUMI_FLUTTER_BIN:-}" ]; then
  exec "$PIKOLUMI_FLUTTER_BIN" "$@"
fi
if command -v flutter >/dev/null 2>&1; then
  exec flutter "$@"
fi
printf '%s\n' 'Install stable Flutter on PATH or set PIKOLUMI_FLUTTER_BIN to its executable.' >&2
exit 1

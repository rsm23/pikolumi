#!/bin/sh
set -eu
export PATH="/Users/rahmaniseif/.cache/pikolumi/flutter/bin:/Users/rahmaniseif/.gem/ruby/4.0.0/bin:/opt/homebrew/opt/ruby/bin:$PATH"
export JAVA_HOME="/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home"
exec /Users/rahmaniseif/.cache/pikolumi/flutter/bin/flutter "$@"

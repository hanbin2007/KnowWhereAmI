#!/bin/sh
# Lets the hosted macOS runner (older Xcode/iOS SDK) build the app for simulator
# screenshots. Only run inside CI: it rewrites tracked files in the checkout.
set -eu
cd "$(dirname "$0")/../.."
cp scripts/ci/SpeechServiceStub.swift App/Speech/OnDeviceSpeechService.swift
sed -i '' 's/\.iOS("27\.0")/.iOS("26.0")/' Package.swift

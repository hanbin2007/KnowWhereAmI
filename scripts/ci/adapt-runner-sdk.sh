#!/bin/sh
# Lets the hosted macOS runner (older Xcode/iOS SDK) build the app for simulator
# screenshots. Only run inside CI: it rewrites tracked files in the checkout.
set -eu
cd "$(dirname "$0")/../.."
cp scripts/ci/SpeechServiceStub.swift App/Speech/OnDeviceSpeechService.swift
cp scripts/ci/AudioSessionGuardStub.swift App/Speech/AudioSessionGuard.swift
sed -i '' 's/\.iOS("27\.0")/.iOS("26.0")/' Package.swift
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 27\.0;/IPHONEOS_DEPLOYMENT_TARGET = 26.0;/' KnowWhereAmI.xcodeproj/project.pbxproj
mkdir -p build

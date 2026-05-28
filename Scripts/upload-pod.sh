#!/bin/zsh
set -e

HEADER_FILE=Sources/MobilyflowSDK/MobilyflowSDK.h
SCRIPT_DIR="$( dirname -- "$0" )"
VERSION=$1

if [[ -z $VERSION ]]; then
  echo "Usage: ./Scripts/upload-pod.sh <version>"
  exit 1
fi

# 1. Go to Root Folder
cd $SCRIPT_DIR/..

# 2. Build header file
rm -f $HEADER_FILE
swiftc -emit-objc-header -emit-objc-header-path $HEADER_FILE \
  -sdk $(xcrun --show-sdk-path --sdk iphoneos) -target arm64-apple-ios15.0 \
  -framework UIKit -framework Foundation -module-name MobilyflowSDK Sources/**/* || true

# 3. Update podspec & version.swift
sed -i '' -E "s/( *s.version *= *)'([0-9a-zA-Z.-]+)'/\1'${VERSION}'/" MobilyflowSDK.podspec

cat > Sources/MobilyflowSDK/version.swift <<EOL
struct MobilyFlowVersion {
    static let current = "${VERSION}"
}
EOL

# 4. Push and tag
git add .
git commit -m "Version ${VERSION}"
git push origin $(git branch --show-current)
git tag "${VERSION}"
git push --tags

# 5. Upload pod
pod trunk push MobilyflowSDK.podspec --allow-warnings

# Note: Pod can take 30 min (sometime hours) to propagate, we can follow the propagation in:
# https://cdn.cocoapods.org/all_pods_versions_2_a_8.txt
# The 2_a_8 correspond of the pod name md5 hash 3 characters,
# ie `echo -n "MobilyflowSDK" | md5` -> 2a8c0fa54fd4c0a4a4dc2154445858cc

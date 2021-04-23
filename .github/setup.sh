#!/bin/sh

set -e

# Environment check
[ -z "$COVERITY_SCAN_PROJECT_NAME" ] && echo "ERROR: COVERITY_SCAN_PROJECT_NAME must be set" && exit 1
[ -z "$COVERITY_SCAN_TOKEN" ] && echo "ERROR: COVERITY_SCAN_TOKEN must be set" && exit 1
[ -z "$COVERITY_SCAN_KEY" ] && echo "ERROR: COVERITY_SCAN_TOKEN must be set" && exit 1

# Create folder
echo "Creating folder..."
COVERITY_TOOL_DIR=/tmp/coverity-scan-analysis
COVERITY_TOOL_NAME=coverity_macosx
mkdir $COVERITY_TOOL_DIR
COVERITY_TOOL_URL=https://scan.coverity.com/download/Darwin
COVERITY_TOOL_KEY_URL=https://scan.coverity.com/download/key

echo "Downloading key..."
wget -nv -O $COVERITY_TOOL_DIR $COVERITY_TOOL_KEY_URL

echo "Downloading tool..."
wget -nv -O $COVERITY_TOOL_DIR/$COVERITY_TOOL_NAME $COVERITY_TOOL_URL --post-data "project=$COVERITY_SCAN_PROJECT_NAME&token=$COVERITY_SCAN_TOKEN"

echo $COVERITY_SCAN_KEY | gpg --import-ownertrust
gpg --output $COVERITY_TOOL_NAME.sh --decrypt $COVERITY_TOOL_DIR/$COVERITY_TOOL_NAME
chmod +x $COVERITY_TOOL_DIR/$COVERITY_TOOL_NAME

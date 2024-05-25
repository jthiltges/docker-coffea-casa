#!/bin/bash

set -e

SOURCE_DIR=${SECRET_SOURCE_DIR:-/source}
TARGET_DIR=${SECRET_TARGET_DIR:-/target}
TARGET_CHOWN=${SECRET_TARGET_CHOWN:-$(id -u):$(id -g)}
TARGET_CHMOD=${SECRET_TARGET_CHMOD:-F0600}

PROGNAME=$(basename $0)

if [ ! -d "$SOURCE_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
  echo "$PROGNAME: Secret source or target does not exist. Exiting."
  exit 0
fi

do_sync () {
  rsync -a \
    --copy-links \
    --exclude=/..*/ \
    --chown="$TARGET_CHOWN" \
    --chmod="$TARGET_CHMOD" \
    "$SOURCE_DIR"/ "$TARGET_DIR"
}

echo "$PROGNAME: Running initial sync"
do_sync

# Wait for the move of the ..data symlink
inotifywait --monitor --event moved_to --timefmt %FT%T%z --format %T \
      "$SOURCE_DIR" \
    | while read timestamp ; do

  echo "$PROGNAME: Secret change at $timestamp"

  do_sync

done

#!/usr/bin/env sh

set -e

# inspect, create, apply
OPERATION="$1"
# postgres-data, sonarqube-data, sonarqube-extensions
VOLUME="$2"
# date; will be in the format 'yyyy-mm-dd' when created automatically
TIMESTAMP="$3"

# validate ops argument
INSPECT='inspect'
CREATE='create'
APPLY='apply'

if [ -z "$OPERATION" ]
then
  printf "You did not specify an operation.\n"
  printf "Available operations are '%s', '%s', and '%s'.\n" "$INSPECT" "$CREATE" "$APPLY"
  exit 2
elif [ "$OPERATION" != "$INSPECT" ] && [ "$OPERATION" != "$CREATE" ] && [ "$OPERATION" != "$APPLY" ]
then
  printf "You failed to specify a valid operation.\n"
  printf "Valid operations are '%s', '%s', and '%s'.\n" "$INSPECT" "$CREATE" "$APPLY"
  exit 2
fi

# validate volume argument
if [ -z "$VOLUME" ]
then
  printf "You did not specify a data volume.\n"
  printf "Available volumes are:\n%s\n" "$(docker volume ls --quiet | grep --ignore-case --invert-match 'backup')"
  exit 2
fi

# validate timestamp argument
if [ "$OPERATION" != "$CREATE" ] && [ -z "$TIMESTAMP" ]
then
  printf "You invoked the '%s' operation omitting the timestamp parameter; this is only allowed for the '%s' operation.\n" "$OPERATION" "$CREATE"
  printf "Available backup timestamps for this volume are:\n%s\n" "$(docker volume ls --quiet | grep --ignore-case "$VOLUME-backup-" | sed -E 's?(.+)(-backup-)(.+)?\3?g')"
  exit 2
elif [ "$OPERATION" = "$CREATE" ] && [ -z "$TIMESTAMP" ]
then
  TIMESTAMP="$(date +'%F')"
fi

# prepare volume access modifiers (read-only, read-write)
READONLY='ro'
READWRITE='rw'
LIVE_ACCESS="$READONLY"
BACKUP_ACCESS="$READONLY"

if [ "$OPERATION" = "$CREATE" ]
then
  BACKUP_ACCESS="$READWRITE"
elif [ "$OPERATION" = "$APPLY" ]
then
  LIVE_ACCESS="$READWRITE"
fi

if [ "$OPERATION" = "$INSPECT" ]
then
# inspect
  docker run \
    -it \
    --rm \
    --volume "$VOLUME:/tmp/live:$LIVE_ACCESS" \
    --volume "$VOLUME-backup-$TIMESTAMP:/tmp/backup:$BACKUP_ACCESS" \
    --workdir '/tmp' \
    alpine:3.10
elif [ "$OPERATION" = "$CREATE" ]
then
# create
  docker volume create "$VOLUME-backup-$TIMESTAMP"
  docker run \
    -it \
    --rm \
    --volume "$VOLUME:/tmp/live:$LIVE_ACCESS" \
    --volume "$VOLUME-backup-$TIMESTAMP:/tmp/backup:$BACKUP_ACCESS" \
    --workdir '/tmp' \
    alpine:3.10 sh -c 'rm -rf /tmp/backup/* && cp -a /tmp/live/* /tmp/backup/'
elif [ "$OPERATION" = "$APPLY" ]
then
# apply
  docker run \
    -it \
    --rm \
    --volume "$VOLUME:/tmp/live:$LIVE_ACCESS" \
    --volume "$VOLUME-backup-$TIMESTAMP:/tmp/backup:$BACKUP_ACCESS" \
    --workdir '/tmp' \
    alpine:3.10 sh -c 'rm -rf /tmp/live/* && cp -a /tmp/backup/* /tmp/live/'
fi

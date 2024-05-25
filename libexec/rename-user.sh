#!/bin/sh

# Rename jovyan user to match COFFEA_USER envvar
NB_USER=${NB_USER:-jovyan}

if [ -n "$COFFEA_USER" && -w /etc/passwd ];
  sed "s/^$NB_USER:/$COFFEA_USER:/" /etc/passwd > /tmp/passwd
  cat /tmp/passwd > /etc/passwd
  rm /tmp/passwd
fi

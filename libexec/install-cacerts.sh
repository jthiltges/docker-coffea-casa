#!/bin/bash

# Loop over a colon-separated list of $CACERT_SOURCE_DIRS
# For each file in a directory, try to get a subject hash
# If successful, add the hash to grid CAs and append to system CAs

SOURCE_DIRS=${CACERT_SOURCE_DIRS:-/cacerts}
TARGET_DIR=${CACERT_TARGET_DIR:-/etc/grid-security/certificates}

PROGNAME=$(basename $0)
OPENSSLDIR=$(openssl version -d | sed 's/OPENSSLDIR: "\(.*\)"/\1/')

IFS=":"
for SRC in $SOURCE_DIRS ; do
  for CERT in $SRC/*
  # Get subject hash
  if HASH=$(openssl x509 -noout -subject_hash -in $CERT) ; then
    # Add CA to grid-security
    cp ${CERT} ${TARGET_DIR}/${HASH}.0
	chmod 644 ${TARGET_DIR}/${HASH}.0
	
	# Add CA to system CAs
	cat ${CERT} >> $OPENSSLDIR/cert.pem
	
	echo "$PROGNAME: Added $CERT to trusted CAs"
  fi
done

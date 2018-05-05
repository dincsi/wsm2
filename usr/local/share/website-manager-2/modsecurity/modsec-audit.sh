#!/bin/bash
#
# Simple script to generate serial-style ModSecurity audit logs
# from per-virtualhost catalogs of all active websites.
# Called via /etc/cron.d/wsm2 as root by default once in every 5 minutes.
#
# Part of website-manager-2 package.

APACHELOGDIR="/var/log/apache2"                         # Root directory for Apache logs
APACHEVHOSTSENDIR="/etc/apache2/sites-enabled"          # Directory for available virtualhosts
GREP="/bin/grep"                                        # grep command call
MODSEC_AUDITGEN="/usr/local/bin/modsec-auditgen"	# modsec-auditgen script call
SED="/bin/sed"                                          # sed command call
SORT="/usr/bin/sort"					# sort command call

# Including headers (if any).
HEADERS="/etc/default/wsm2-modsec-audit"
if [ -r "$HEADERS" ]; then . $HEADERS; fi

# Silent exit on disabled.
if [ "$AUDIT_HANDLE" -eq 0 ]; then exit $EXIT_SUCC; fi

# Creating a unique ABC-sorted list of active virtualhosts.
$GREP -Rh 'ServerName' "$APACHEVHOSTSENDIR" | \
$GREP -v '#' | \
$SED "s/^.*ServerName\s*\(\S*\).*$/\1/" | \
$SORT -u | while read vhost
do
    # Paralell call of processor scripts (modsec-auditgen) for all virtualhost.
    ($MODSEC_AUDITGEN $APACHELOGDIR/$vhost-audit.log $APACHELOGDIR/$vhost-modsec.log) &
done
# Call processor script for ALLHOSTS-audit.log also.
($MODSEC_AUDITGEN $APACHELOGDIR/ALLHOSTS-audit.log $APACHELOGDIR/ALLHOSTS-modsec.log) &

# Finished.

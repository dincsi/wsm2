#!/bin/bash
#
# SSL Certificate Revoking List (CRL) refresher for website-manager-2.
# Enumerates active virtualhosts and calls the 'wsm2 --revoke' to do the job.
# Called from /etc/cron/wsm2 once a week (Sunday, late night).
#
# Part of website-manager-2 package.

APACHEVHOSTSENDIR="/etc/apache2/sites-enabled"          # Directory for available virtualhosts
GREP="/bin/grep"                                        # grep command call
SED="/bin/sed"                                          # sed command call
SORT="/usr/bin/sort"                                    # sort command call
WSM2="/usr/local/bin/wsm2"				# wsm2 vommand call

# Creating a unique ABC-sorted list of active virtualhosts.
$GREP -Rh 'ServerName' "$APACHEVHOSTSENDIR" | \
$GREP -v '#' | \
$SED "s/^.*ServerName\s*\(\S*\).*$/\1/" | \
$SORT -u | while read vhost
do
    # Silent, the results will be logged into /var/log/wsm2.log
    "$WSM2" --revoke "$vhost" >/dev/null 2>&1
done

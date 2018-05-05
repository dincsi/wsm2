#!/bin/bash
#
# Simple script to distribute urlcheck_scanhost results into vhost logs.
# Part of website-manager-2 package.

APACHECOMMONLOG="ALLHOSTS"                              # Filename for common weblogs
APACHELOGDIR="/var/log/apache2"                         # Root directory for Apache logs
AWK="/usr/bin/awk"                                      # awk command call
SED="/bin/sed"                                          # sed command call
URLCHECK_SUFFIX="-urlcheck.log"                         # suffix for urlcheck logs

# Including headers (if any). 
HEADERS="/etc/default/wsm2-urlcheck"
if [ -r "$HEADERS" ]; then . $HEADERS; fi

# Getting result of urlcheck_scanhost.
cat | while read LINE
do
    # All goes to common log.
    echo "$LINE" >> "$APACHELOGDIR/$APACHECOMMONLOG$URLCHECK_SUFFIX"
    # Greping 3rd field of the line as hostname.
    HOST=`echo "$LINE" | $AWK '{print $3}' | $SED "s/^\(.*\:\/\/\)\?\(\(\([0-9a-zA-Z_-]\)\+\.\)\+\([0-9a-zA-Z]\)\+\)\(.*$\)/\2/"`
    # Distributing into vhost log (creating if isn't found).
    if [ ! -f "$APACHELOGDIR/$HOST$URLCHECK_SUFFIX" ]; then
        touch "$APACHELOGDIR/$HOST$URLCHECK_SUFFIX" 
        chmod 640 "$APACHELOGDIR/$HOST$URLCHECK_SUFFIX"
    fi
    if [ -f "$APACHELOGDIR/$HOST$URLCHECK_SUFFIX" ]; then
        echo "$LINE" >> "$APACHELOGDIR/$HOST$URLCHECK_SUFFIX"
    fi
done

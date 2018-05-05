#!/bin/bash
#
# Simple script to check all enabled SeverName URLs and URLs given manually.
# Call periodically from cron, then provides a simple webcron function also.
# Part of website-manager-2 package.

APACHEVHOSTSENDIR="/etc/apache2/sites-enabled"          # Directory for enabled virtualhosts
AWK="/usr/bin/awk"                                      # awk command call
EXCEPTURL=""                                            # | delimited list - deprecated
EXIT_ERR="1"                                            # Exit code on error
EXIT_SUCC="0"                                           # Exit code on success
GREP="/bin/grep"                                        # grep command call
URLCHECKOK="\( 200 (\)\|\( 200 OK\)"                    # successfull urlcheck result code
SED="/bin/sed"                                          # sed command call
SORT="/usr/bin/sort"					# sort command call
URLCHECK="/usr/local/bin/urlcheck"                      # urlcheck pathname
URLCHECK_EXC="/etc/apache2/urlcheck.exception"          # urlcheck exceptions file pathname
URLCHECK_HOSTS="/etc/apache2/urlcheck.hosts"            # urlcheck hosts file pathname
URLCHECKNOCHECK="NOCHECK"                               # don't check exception token
URLCHECKTIMEOUT=30                                      # urlcheck default timeout (secs)

MSG_WSM_URLCHECK_NOSCRIPT="Fatal: $URLCHECK isn't found!"

# Including headers (if any).
HEADERS="/etc/default/wsm2-urlcheck"
if [ -r "$HEADERS" ]; then . $HEADERS; fi

# Checking urlcheck script.
if [ ! -x "$URLCHECK" ]; then
    echo -e "$MSG_WSM_URLCHECK_NOSCRIPT" >&2
    exit $EXIT_ERR
fi

# Checking listed URLs - one URL per line, empty lines and hashmark comments allowed.
if [ ! -z "`cat $URLCHECK_HOSTS 2>/dev/null | $AWK '{ if ($0 !~ /^#.*/) print $0 }' | $AWK 'NF > 0'`" ] ; then
    cat "$URLCHECK_HOSTS" | \
    $AWK '{ if ($0 !~ /^#.*/) print $0 }' | \
    $AWK 'NF > 0' | while read SRVNM
    do
        if [ -z "echo $SRVNM | $GREP '://'" ]; then 
            URL="http://$SRVNM"
        else
            URL="$SRVNM"
        fi
        RESULT=`$URLCHECK $URL $URLCHECKTIMEOUT`
        # All results to stdout, errors to stderr also.
        echo $RESULT
        echo $RESULT | $GREP -vi "$URLCHECKOK" >&2
    done
fi

# Parsing exceptions - a line contains an original URL, a whitespace
# and an URL to check or NOCHECK token. Empty lines and hashmark comments allowed.
if [ -r "$URLCHECK_EXC" ] ; then
    EXCEPTURL=`echo -n $EXCEPTURL; cat $URLCHECK_EXC | \
               $AWK '{ if ($0 !~ /^#.*/) print $0 }' | \
               $AWK 'NF > 0' | while read LINE
               do
                   echo "$LINE |"
               done`
fi

# Checking available ServerNames, considering exceptions.
$GREP -Rh "ServerName" $APACHEVHOSTSENDIR | $GREP -v '#' | $SED -e "s/ServerName//" | $SORT -u | \
while read SRVNM
do
    URL=`echo $EXCEPTURL | $AWK 'BEGIN { RS = "|" } ; { if ($1 == SRVNM) print $2 }' SRVNM=$SRVNM`
    if [ -z "$URL" ] ; then
        URL=$SRVNM
    fi
    # Skip NOCHECK tokened items.
    if [ "$URL" != "$URLCHECKNOCHECK" ] ; then
        if [ -z "echo $URL | $GREP '://'" ]; then 
            URL="http://$URL" 
        fi
        RESULT=`$URLCHECK $URL $TIMEOUT`
        # All results to stdout, errors to stderr also.
        echo $RESULT 
        echo $RESULT | $GREP -vi "$URLCHECKOK" >&2
    fi
done

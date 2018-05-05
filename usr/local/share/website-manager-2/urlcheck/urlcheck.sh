#!/bin/bash
#
# Simple script to check an URL. Part of website-manager-2 package.
# Call: urlcheck URL [timeout_in_sec]

# Defaults and messages (for standalone use) - maybe overriden via header.
DATE="/bin/date"                                # date command call
EXIT_ERR="1"                                    # Exit code on error
EXIT_SUCC="0"                                   # Exit code on success
GREP="/bin/grep"                                # grep command call
SED="/bin/sed"                                  # sed command call
URLCHECKAGENT="urlcheck-robot"                  # urlcheck browser agent name
URLCHECKTIMEOUT=30                              # urlcheck default timeout (secs)
WGET="/usr/bin/wget"                            # wget command call

MSG_WSM_URLCHECK_FATAL="000 Fatal!"
MSG_WSM_URLCHECK_USAGE="Usage: $0 URL_to_check [ timeout_in_seconds ]"

# Including headers (if any).
HEADERS="/etc/default/wsm2-urlcheck"
if [ -r "$HEADERS" ]; then . $HEADERS; fi

# Getting parameters.
URL="$1"; shift                         # URL to check
TIMEOUT=${1:-$URLCHECKTIMEOUT}; shift   # Wget timeout

# URL required.
if [ ! -z "$URL" ] ; then
    START=`$DATE '+%Y:%m:%d:%H:%M:%S'`
    # Wget call: spider mode, getting HTTP response from header - only one try.
    RESULT=`$WGET "$URL" --spider -S --no-check-certificate --keep-session-cookies -t 1 -U $URLCHECKAGENT -T $TIMEOUT 2>&1 | $GREP 'HTTP/'`
    END=`$DATE '+%Y:%m:%d:%H:%M:%S'`
    # Default response when no result.
    if [ -z "$RESULT" ] ; then
        RESULT="$MSG_WSM_URLCHECK_FATAL"
    fi
    echo "$START $END $URL `echo $RESULT |  $SED -n 's/^.*\([[:digit:]]\{3\}\)\(:*\)\(.*$\)/\1\3/p'`"

# On error printing usage reminder.
else
    echo -e "$MSG_WSM_URLCHECK_USAGE" >&2
    exit $EXIT_ERR
fi

#!/bin/bash
#
# Simple script to make a monthly AwStats HTML result page of given virtualhost.
# Usage: $0 servername [path_to_generate_rootdir [year [month]]]
# Part of website-manager-2 package.

# Common literals for standalone use - maybe overriden by headers.

APACHEADMIN="webadmin"                                  # Linux user for web administration
APACHEADMINGROUP="www-data"                             # Linux group for web administration
EXIT_ERR="1"                                            # Error code on failure
FIND="/usr/bin/find"                                    # find command call
LANGUAGE=hu                                             # HTML results language
STATS_ROOT_DIR="/var/www/awstats"                       # Web results directory

awstats_buildstatic="/usr/local/bin/awstats_buildstaticpages.pl"
awstats_program="/usr/lib/cgi-bin/awstats.pl"

MSG_WSM_AWSTATSPAGE_USAGE="Usage: $0 servername [path_to_generate_rootdir [year [month]]]"

# Including header (if any).
HEADER="/etc/default/wsm2-awstats"
if [ -r "$HEADER" ]; then . $HEADER; fi

# Getting parameters.
if [ -z "$1" ]; then echo "$MSG_WSM_AWSTATSPAGE_USAGE" >&2; exit $EXIT_ERR; fi
SRVNM="$1"; shift
if [ ! -z "$1" -a ! -d "$1" ]; then  echo "$MSG_WSM_AWSTATSPAGE_USAGE" >&2; exit $EXIT_ERR; fi
STATS_ROOT_DIR=${1:-$STATS_ROOT_DIR}; shift
if [ ! -d "$STATS_ROOT_DIR" ]; then exit; fi
YEAR=${1:-$(date '+%Y')}; shift
MONTHALL=""
if [ -z "$1" ]; then MONTHALL="all"; fi
MONTH="$1"; shift

# Creating directory if necessary; doing some cleanup.
if [ ! -d "$STATS_ROOT_DIR/$SRVNM" ]; then
    mkdir -m 2750 --verbose "$STATS_ROOT_DIR/$SRVNM"
    chown $APACHEADMIN:$APACHEADMINGROUP $STATS_ROOT_DIR/$SRVNM
fi
if [ ! -d "$STATS_ROOT_DIR/$SRVNM/$YEAR$MONTH" ]; then
    mkdir -m 2750 --verbose $STATS_ROOT_DIR/$SRVNM/$YEAR$MONTH
    chown $APACHEADMIN:$APACHEADMINGROUP $STATS_ROOT_DIR/$SRVNM/$YEAR$MONTH
fi
rm -f $STATS_ROOT_DIR/$SRVNM/$YEAR$MONTH/*
# Generating HTML pages itself.
$awstats_buildstatic \
    -config=$SRVNM \
    -lang=$LANGUAGE \
    -awstatsprog=$awstats_program \
    -year=$YEAR \
    -month=$MONTH$MONTHALL \
    -dir=$STATS_ROOT_DIR/$SRVNM/$YEAR$MONTH \
    >/dev/null 2>&1
# Fixing access rights.
$FIND $STATS_ROOT_DIR/$SRVNM/$YEAR$MONTH -type d \
    -exec chmod 2750 {} \; -exec chown $APACHEADMIN:$APACHEADMINGROUP {} \;
$FIND $STATS_ROOT_DIR/$SRVNM/$YEAR$MONTH -type f \
    -exec chmod 640 {} \; -exec chown $APACHEADMIN:$APACHEADMINGROUP {} \;

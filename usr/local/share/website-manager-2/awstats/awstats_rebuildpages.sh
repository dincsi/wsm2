#!/bin/bash
#
# Simple recovery script to rebuild (lost) AwStats HTML result pages.
# Don't hurts existing files.
# Part of website-manager-2 package.

# Common literals for standalone use - maybe overriden by headers.

AWK="/usr/bin/awk"                                      # awk command call
AWSTATS_DATADIR="/var/lib/awstats"                      # AwStats database folder
BASENAME="/usr/bin/basename"                            # basename command call
EXIT_ERR="1"                                            # Error code on failure
SED="/bin/sed"                                          # sed command call
STATS_ROOT_DIR="/var/www/awstats"                       # Web results directory

awstats_build="/usr/local/share/website-manager-2/awstats/awstats_buildmonthpage.sh"
awstats_bmenu="/usr/local/share/website-manager-2/awstats/awstats_buildmenupages.sh"

# Including header (if any).
HEADER="/etc/default/wsm2-awstats"
if [ -r "$HEADER" ]; then . $HEADER; fi

if [ ! -z "$1" -a ! -d "$1" ]; then  echo "Usage: $0 path_to_stats_rootdir" >&2; exit $EXIT_ERR; fi
STATS_ROOT_DIR=${1:-$STATS_ROOT_DIR}; shift
if [ ! -d "$STATS_ROOT_DIR" ]; then exit; fi

# Enumerating database files.
ls -1 "$AWSTATS_DATADIR" | while read DATAFILE
do
    DATAFILE=$($BASENAME $DATAFILE)
    # Parsing filename (format: awstatsMMYYYY.hostname.txt).
    SRVNM=`echo $DATAFILE | $SED "s/^awstats.\{6\}\.//" | $SED "s/\.txt\$//"`
    YEAR=`echo $DATAFILE | $AWK '{ print substr($0, 10, 4) }'`
    MONTH=`echo $DATAFILE | $AWK '{ print substr($0, 8, 2) }'`
    # Rebuilding yearly HTMLs if necessary.
    if [ ! -d "$STATS_ROOT_DIR/$SRVNM/$YEAR" ]; then
        $awstats_build "$SRVNM" "$STATS_ROOT_DIR" "$YEAR"
        $awstats_bmenu "$STATS_ROOT_DIR/$SRVNM"
    else
        echo "Skipped $SRVNM - $YEAR"
    fi
    # Rebuilding monthly HTMLs if necessary.
    if [ ! -d "$STATS_ROOT_DIR/$SRVNM/$YEAR$MONTH" ]; then
        $awstats_build "$SRVNM" "$STATS_ROOT_DIR" "$YEAR" "$MONTH"
        $awstats_bmenu "$STATS_ROOT_DIR/$SRVNM"
    else
        echo "Skipped $SRVNM - $YEAR - $MONTH"
    fi
done


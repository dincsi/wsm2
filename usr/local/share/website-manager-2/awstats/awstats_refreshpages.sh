#!/bin/bash
#
# Simple script to refresh all statistic webpages (current month and year)
# according to AwStats configuration files.
# Running once a day from cron (cron.daily - after updtaing statistics)
# is recommended.
# Part of website-manager-2 package.

# Common literals for standalone use - maybe overriden by headers.

AWSTATS_CONFIG="/etc/awstats"                           # AwStats configuration directory
DATE="/bin/date"                                        # date command call
EXIT_ERR="1"                                            # Error code on failure
SED="/bin/sed"                                          # sed command call
STATS_ROOT_DIR="/var/www/awstats"                       # Web results directory

awstats_build="/usr/local/share/website-manager-2/awstats/awstats_buildmonthpage.sh"
awstats_bmenu="/usr/local/share/website-manager-2/awstats/awstats_buildmenupages.sh"

# Including header (if any).
HEADER="/etc/default/wsm2-awstats"
if [ -r "$HEADER" ]; then . $HEADER; fi

# Not redefineable literals.
YEAR=`$DATE '+%Y'`                               # Current year
YEAR_1=`$DATE '+%Y' -d "1 year ago"`             # Year before
MONTH=`$DATE '+%m'`                              # Current month
MONTH_1=`$DATE '+%m' -d "1 month ago"`           # Month before
DAY=`$DATE '+%d'`                                # Current day

# Getting parameters.
if [ ! -z "$1" -a ! -d "$1" ]; then  echo "Usage: $0 path_to_stats_rootdir" >&2; exit $EXIT_ERR; fi
STATS_ROOT_DIR=${1:-$STATS_ROOT_DIR}; shift
if [ ! -d "$STATS_ROOT_DIR" ]; then exit; fi

# Enumerating existing AwStats configurations.
ls -1 $AWSTATS_CONFIG/awstats.*.conf 2>/dev/null | \
    $SED "s/^.*\/awstats\.//" | $SED "s/\.conf\$//" | while read SRVNM
do
    if [ ! -z "$SRVNM" ]; then
        # Rebuilding yearly statistics HTMLs.
        $awstats_build "$SRVNM" "$STATS_ROOT_DIR" "$YEAR"
        # Rebuilding monthly statistics HTMLs.
        $awstats_build "$SRVNM" "$STATS_ROOT_DIR" "$YEAR" "$MONTH"
        # Every 1st day of a month we need refresh some early pages also.
        if [ $DAY -eq 1 ]; then
            # On 1st January the previous year and the last month of previous year;
            if [ $MONTH -eq 1 ]; then
                $awstats_build "$SRVNM" "$STATS_ROOT_DIR" "$YEAR_1"
        	$awstats_build "$SRVNM" "$STATS_ROOT_DIR" "$YEAR_1" "$MONTH_1"
	    # Else the month before of this year only.
	    else
        	$awstats_build "$SRVNM" "$STATS_ROOT_DIR" "$YEAR" "$MONTH_1"
            fi
        fi
        # Rebuilding virtualhost's menu page.
        $awstats_bmenu "$STATS_ROOT_DIR/$SRVNM"
    fi
done

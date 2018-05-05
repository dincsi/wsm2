#!/bin/bash
#
# Simple script for AwStats web statistics daily maintenance.
# Running once a day from cron (cron.daily) is recommended.
# Part of website-manager-2 package.

# Common literals for standalone use - maybe overriden by headers.

AWSTATS_CONFIG="/etc/awstats"                           # AwStats configuration directory
EXIT_ERR="1"                                            # Error code on failure
STATS_ROOT_DIR="/var/www/awstats"                       # Web results directory

awstats_program="/usr/lib/cgi-bin/awstats.pl"
awstats_refresh="/usr/local/share/website-manager-2/awstats/awstats_refreshpages.sh"
awstats_scanhosts="/usr/local/share/website-manager-2/awstats/awstats_scanhosts.sh"
awstats_updateall="/usr/local/bin/awstats_updateall.pl"

# Including header (if any).
HEADER="/etc/default/wsm2-awstats"
if [ -r "$HEADER" ]; then . $HEADER; fi

# Getting parameters.
if [ ! -z "$1" -a ! -d "$1" ]; then  echo "Usage: $0 path_to_stats_rootdir" >&2; exit $EXIT_ERR; fi
STATS_ROOT_DIR=${1:-$STATS_ROOT_DIR}; shift
if [ ! -d "$STATS_ROOT_DIR" ]; then exit; fi

# Checking AwStats and Apache configurations, creating missing AwStats.
$awstats_scanhosts
# Updating AwStats databases for existing configurations (silently).
$awstats_updateall now -awstatsprog=$awstats_program -confdir=$AWSTATS_CONFIG >/dev/null 2>&1
# Refresh static HTML pages (silently).
$awstats_refresh "$STATS_ROOT_DIR"

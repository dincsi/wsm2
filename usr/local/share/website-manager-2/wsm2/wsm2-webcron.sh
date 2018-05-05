#!/bin/bash
#
# Webcron service for website-manager-2.
# Find web crontabs in active websites document root and execute them.
# Called from /etc/cron.d/wsm2 minutely as webadmin.
#
# Part of website-manager-2 package.

APACHEVHOSTSENDIR="/etc/apache2/sites-enabled"          # Directory for available virtualhosts
DATE="/bin/date"                                        # date command call
GREP="/bin/grep"                                        # grep command call
MASKHTTP="^\(http\(s\)\?:\/\/\)\?"			# SED regexp: http(s) protocol
MASKWEB="\(\([0-9a-zA-Z_-]\)\+\.\)\+\([0-9a-zA-Z]\)\+"  # SED regexp: valid website name
SED="/bin/sed"                                          # sed command call
SORT="/usr/bin/sort"                                    # sort command call
URLCHECK="/usr/local/bin/urlcheck"                      # urlcheck pathname
WEBCRONLOG="log/webcron.log"				# logfile relative pathname
WEBCRONPARSER="/usr/local/bin/wsm2-webcron-parser"	# webcron parser call
WEBCRONTAB=".htcrontab"					# Crontab file name for a vhost

MSG_WSM_WEBCRON_WRONGURL="000 Fatal! Wrong URL"

# Including headers (if any).
HEADERS="/etc/default/wsm2-modsec-webcron"
if [ -r "$HEADERS" ]; then . $HEADERS; fi

# Simple logger function to write urlcheck-style error messages.
function errorlog {

    DATETIME=`$DATE '+%Y:%m:%d:%H:%M:%S'`
    echo -e "$DATETIME $DATETIME $*" >>"$docroot/$WEBCRONLOG"
    return
}

# Creating a unique ABC-sorted list of document roots for active virtualhosts.
$GREP -Rh 'DocumentRoot' "$APACHEVHOSTSENDIR" 2>/dev/null | \
$GREP -v '#' | \
$SED "s/^.*DocumentRoot\s*\(\S*\).*$/\1/" | \
$SORT -u | while read docroot
do
    # Getting webcron file (if any) and parsing for actual jobs.
    if [ -r "$docroot/$WEBCRONTAB" ]; then
	joblines="$(cat "$docroot/$WEBCRONTAB" | $WEBCRONPARSER)"
	# Job commands are urlcheck parameters.
	# Formally checking joblines then starting a separate urlcheck for each.
	echo -e "$joblines" | while read jobline
	do
	    url="$(echo -e "$jobline" | cut -d ' ' -f 1)"
	    # Sanitizing URL: http(s)://$MASKWEB(/anything) accepted.
	    if [ ! -z "`echo "$url" | $SED "s/$MASKHTTP$MASKWEB\(\/\)\?.*$//"`" ]; then
		errorlog "$url $MSG_WSM_WEBCRON_WRONGURL"
		url=""
	    fi
	    # Sanitizing timeout: not negative integer accepted.
	    timeout="$(echo -e "$jobline" | cut -d ' ' -f 2)"
	    if [ ! -z "`echo "$timeout" | $SED "s/[0-9]*//"`" ]; then
		timeout=""
	    fi
	    # Calling urlcheck as a separate process,
	    # using virtualhost's urlcheck.log.
	    if [ ! -z "$url" ]; then
		("$URLCHECK" "$url" "$timeout" >>"$docroot/$WEBCRONLOG" 2>/dev/null) &
	    fi
	done
    fi
done

# Finished.

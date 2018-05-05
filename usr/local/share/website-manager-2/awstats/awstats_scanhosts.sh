#!/bin/bash
#
# Simple script to check consistency of Apache vitrualhosts and AwStats
# configuration files. Creates missing AwStats configurations (if any)
# and sends a warning about orphaned AwStats objects (if any).
#
# Running once a day from cron (cron.daily) is recommended.
# Part of website-manager-2 package.

# Common literals for standalone use - maybe overriden by headers.

APACHE_DIR="/etc/apache2"                               # Apache configuration base directory
APACHE_LOG_DIR="/var/log/apache2"                       # Apache log directory
APACHE_AHOSTS="$APACHE_DIR/sites-available"             # Available virtualhosts directory
APACHE_VHOSTS="$APACHE_DIR/sites-enabled"               # Enabled virtualhosts directory
AWK="/usr/bin/awk"                                      # awk command call
AWSTATS_CONFIG="/etc/awstats"                           # AwStats configuration directory
AWSTATS_DATADIR="/var/lib/awstats"                      # AwStats database directory
AWSTATS_EXC="$APACHE_DIR/awstats.exception"             # Parsed exception file
AWSTATS_HOSTS="$APACHE_DIR/awstats.hosts"               # Parsed hosts file
AWSTATS_TEMPLATE="$AWSTATS_CONFIG/awstats.conf.template"        # AwStats template
EXIT_ERR="1"                                            # Error code on failure
GREP="/bin/grep"                                        # grep command call
IFCONFIG="/sbin/ifconfig"                               # ifconfig command call
NOSTAT="NOSTAT"                                         # Exclusion token
SED="/bin/sed"                                          # sed command call
STATS_ROOT_DIR="/var/www/awstats"                       # Web results directory

# Including header (if any).
HEADER="/etc/default/wsm2-awstats"
if [ -r "$HEADER" ]; then . $HEADER; fi

EXCEPTLIST=""                                           # Exceptions list (deprecated)
SERVERLIST=""                                           # Servers list (deprecated)

# Determining own IP addresses by parsing ipconfig output.
SERVERIPS=""
if [ -x $IFCONFIG ]; then
    SERVERIPS=`echo $($IFCONFIG | $GREP 'inet addr:' | $SED "s/[[:space:]]*inet addr:\([^ ]*\).*/\1/")`
fi

# check_host servername
# Checks this virtualhost, sends warning if corresponding Apache
# logfile is absent. Lack of AwStats configuration creates them.
function check_host {

    local ServerName="$1"; shift
    if [ -z "$ServerName" ]; then return $EXIT_ERR; fi
    local datetime=`date '+%Y-%m-%d %H:%M'`

    # Checking corresponding Apache logfile.
    local logfile="$APACHE_LOG_DIR/$ServerName-access.log"
    if [ ! -f "$logfile" ]; then cat >&2 << EOF
ERROR from $0:
Missing $logfile!
When $ServerName's access log isn't $logfile, write a modifier line into $AWSTATS_EXC file.

EOF
        return $EXIT_ERR
    fi

    # Checking corresponding AwStats configuration.
    if [ ! -f "$AWSTATS_CONFIG/awstats.$ServerName.conf" ]; then
        export ServerName SERVERIPS APACHE_LOG_DIR logfile datetime
        cat $AWSTATS_TEMPLATE | envsubst >$AWSTATS_CONFIG/awstats.$ServerName.conf
        cat >&1 << EOF
INFO from $0: New host!
Successfully created AwStats configuration for virtualhost $ServerName.

EOF
    fi
    return
}

# Checking listed ServerNames - one SeverName per line,
# empty lines and hashmark comments allowed.
SERVERHOSTS=$(cat "$AWSTATS_HOSTS" 2>/dev/null | \
            $AWK '{ if ($0 !~ /^#.*/) print $0 }' | \
            $AWK 'NF > 0')
for SRVNM in $SERVERHOSTS
do
    check_host "$SRVNM"
done

# Parsing exceptions - a line contains an original ServerName, a whitespace
# and a substitute ServerName or a NOSTAT token.
# Empty lines and hashmark comments allowed.
if [ -r "$AWSTATS_EXC" ] ; then
    EXCEPTLIST=`echo -n $EXCEPTLIST; cat $AWSTATS_EXC 2>/dev/null | \
                   $AWK '{ if ($0 !~ /^#.*/) print $0 }' | \
                   $AWK 'NF > 0' | while read line
                    do
                        echo "$line |"
                    done`
fi

# Makes a list of enabled ServerNames considering exceptions.
# Warning: all names goes to list two times (from http/https config).
SERVERLIST=$($GREP -Rh "ServerName" $APACHE_VHOSTS  | \
            $GREP -v '#' | $SED -e "s/ServerName//" |while read ServerName
                do
                    # Checks for exceptions list, change if necessary.
                    changed=`echo $EXCEPTLIST | $AWK 'BEGIN { RS = "|" } ; { if ($1 == TOCHECK) print $2 }' TOCHECK=$ServerName`
                    if [ ! -z "$changed" ] ; then 
                        if [ "$changed" != $NOSTAT ]; then echo -n "$changed "; fi
                    else
                        echo -n "$ServerName "
                    fi
                done)
# Checking result list.
for SRVNM in $SERVERLIST
do
    check_host "$SRVNM"
done
# Ready with existing configurations.

# Searching orphaned AwStats configurations (with no corresponding
# Apache configuration). We don't need alerts for disabled vhosts,
# therefore we need recreate the SERVERLIST considering all available
# (not only actually enabled) vhosts.

# Makes a list of available(!) ServerNames considering exceptions.
# Warning: all names goes to list two times (from http/https config).
SERVERLIST=$($GREP -Rh "ServerName" $APACHE_AHOSTS  | \
            $GREP -v '#' | $SED -e "s/ServerName//" |while read ServerName
                do
                    # Checks for exceptions list, change if necessary.
                    changed=`echo $EXCEPTLIST | $AWK 'BEGIN { RS = "|" } ; { if ($1 == TOCHECK) print $2 }' TOCHECK=$ServerName`
                    if [ ! -z "$changed" ] ; then 
                        if [ "$changed" != $NOSTAT ]; then echo -n "$changed "; fi
                    else
                        echo -n "$ServerName "
                    fi
                done)
# Enumerating available AwStats configurations and finding the corresponding vhost.
# Sending an orphan alert, if isn't found.
ls -1 $AWSTATS_CONFIG/awstats.*.conf 2>/dev/null | \
$SED "s/^.*\/awstats\.//" | $SED "s/.conf\$//" | while read ConfigName
do
    if [ -z "`echo " $SERVERHOSTS $SERVERLIST " | $SED -n s/[[:space:]]\*$ConfigName[[:space:]]\*/X/p`" ]; then
        cat >&1 << EOF
WARNING from $0: Orphan configuration!
Virtualhost $ConfigName represented in $AWSTATS_CONFIG but isn't found in available virtualhosts' list. If maintain webstatistics about $ConfigName is unnecessary, consider deleting following files also (if any):
$AWSTATS_CONFIG/awstats.$ConfigName.conf
$AWSTATS_DATADIR/awstats??????.$ConfigName.txt
$STATS_ROOT_DIR/$ConfigName

EOF
    fi
done

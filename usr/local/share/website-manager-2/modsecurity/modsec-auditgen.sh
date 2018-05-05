#!/bin/bash
#
# Simple script to generate a serial-style ModSecurity audit log
# from a catalog and set of concurrent-logged audit entries.
#
# Part of website-manager-2 package.

AUDIT_HANDLE=1						# Set 0 to disable
if [ -d "/var/lib/mod_security/AuditLogDir" ]; then	# wsm2 before v2.6 compatibility
    AUDITLOGDIR="/var/lib/mod_security/AuditLogDir"     # Audit events folder (old)
else							# wsm2 v2.6+
    AUDITLOGDIR="/var/lib/modsecurity/AuditLogDir"      # Audit events folder (new)
fi
BASENAME="/usr/bin/basename"				# basename command call
DATE="/bin/date"                                        # date command call
EXIT_ERR="1"                                            # Exit code on error
EXIT_SUCC="0"                                           # Exit code on success
GREP="/bin/grep"                                        # grep command call
PS="/bin/ps"						# ps command call
SED="/bin/sed"						# sed command call
TAIL="/usr/bin/tail"                                    # tail command call
WC="/usr/bin/wc"					# wc command call
WHOAMI="/usr/bin/whoami"                                # whoami command call
WSMLOGFILE="/var/log/wsm2.log"                          # Logfile for wsm2 itself

MSG_WSM_MODSEC_AGENERR="Error serializing audit log:"
MSG_WSM_MODSEC_DUPLICATED="Another copy of $($BASENAME $0) is running."
MSG_WSM_MODSEC_MISSCAT="Auditlog catalog isn't found:"
MSG_WSM_MODSEC_NEWAUDIT="New audit log found:"
MSG_WSM_MODSEC_NEWCAT="New catalog found:"
MSG_WSM_MODSEC_NOCREACAT="Unable to create serialized audit log:"
MSG_WSM_MODSEC_ROOTNEED="Must be root."
MSG_WSM_MODSEC_USAGE="Usage: $0 auditlog_catalog_file_pathname auditlog_file_pathname"

# Including headers (if any).
HEADERS="/etc/default/wsm2-modsec-audit"
if [ -r "$HEADERS" ]; then . $HEADERS; fi

# Silent exit on disabled.
if [ "$AUDIT_HANDLE" -eq 0 ]; then exit $EXIT_SUCC; fi

#
# Functions
#

# Helper function: logs with timestamp into a logfile and native to STD_ERR.
function log {

    local DATETIME="+%d/%b/%Y:%H:%M:%S %Z"
    if [ -f "$WSMLOGFILE" -a -w "$WSMLOGFILE" ]; then
        echo -e "[$($DATE "$DATETIME")] $($WHOAMI) ${FUNCNAME[1]} $*" >>$WSMLOGFILE
        echo -e "$*" >&2
    else
        echo -e "[$($DATE "$DATETIME")] $($WHOAMI) ${FUNCNAME[1]} $*" >&2
    fi
    return
}

#
# Main program
#

# Must be root.
if [ ! $UID -eq 0 ]; then log $MSG_WSM_MODSEC_ROOTNEED; return $EXIT_ERR; fi

# Stops if another copy is already running.
instances=$($PS aux)
instances=$(echo -e "$instances" | $GREP -i $($BASENAME $0) | $GREP -i "$1" | $GREP -i "$2" |$GREP -iv "$GREP" | $WC -l)
if [ "$instances" -gt 1 ]; then
    log "$MSG_WSM_MODSEC_DUPLICATED"; exit $EXIT_ERR
fi

# Getting parameters.
# Catalog file pathname required and must readable.
catalog=$1; shift
if [ -z "$catalog" ]; then log "$MSG_WSM_MODSEC_USAGE"; exit $EXIT_ERR; fi
if [ ! -f "$catalog" ]; then log "$MSG_WSM_MODSEC_MISSCAT $catalog"; exit $EXIT_ERR; fi
# Catalog file is ready.

# Serialized audit log file pathname required.
auditlog=$1; shift
if [ -z "$auditlog" ]; then log "$MSG_WSM_MODSEC_USAGE"; exit $EXIT_ERR; fi
# Create if isn't found.
if [ ! -f "$auditlog" ]; then
    touch "$auditlog" >/dev/null 2>&1; RESULT=$?
    if [ $RESULT -ne 0 ]; then log "$MSG_WSM_MODSEC_NOCREACAT $auditlog"; exit $EXIT_ERR; fi
    chown root:root "$auditlog"; chmod 640 "$auditlog"
fi
# Audit log is ready.

# Parsing audit log, looking for last entry's catalog line.
# Any catalog item before the last entry (including them) is already serialized.
# All catalog entries after the last entry needs to be serialized.
RESULT=$({
lastentry="$($TAIL -n 2 "$auditlog" | $GREP -E ' md5:[a-z0-9]{32}[[:blank:]]?$')"
# Empty lastentry indicates a new, empty (e.g. rotated) auditlog.
if [ -z "$lastentry" ]; then echo -ne "NEW|"; fi
# Reading catalog sequentially, searching for lastentry.
cat "$catalog" |  while read logentry
do
    # Skipping any records before lastentry;
    # leaving a sign when lastentry reached.
    if [ ! -z "$lastentry" ]; then
	# When lastentry found, all remaining records needs to be serialized.
	if [ "$lastentry" == "$logentry" ]; then lastentry=""; echo -ne "FOUND|"
	# Else simply skip record.
	else echo -ne "SKIP|"
	fi
    # When lastentry is empty, we need serialize all (remaining) records.
    else
	# Parsing relative pathname of an audit entry (dirty, TODO!).
	auditentry=$(echo "$logentry" | cut -d ' ' -f 16)
	# Copy corresponding audit entry into serialized auditlog,
	# followed by the catalog line as a marker.
	cat "$AUDITLOGDIR/$auditentry" >>$auditlog
	echo "$logentry" >>$auditlog
	echo -ne "ADD|"
    fi
done
})
# Debug: uncomment lines below.
##echo "$RESULT"
##exit 0

# Empty result indicates empty catalog - nothing to do.
if [ -z "$RESULT" ]; then exit $EXIT_SUCC; fi

# Result containing any words except NEW| SKIP| FOUND| ADD| indicates
# some error message written in STDOUT - we need leave a log message
# and exit.
ERRMSG=$(echo $RESULT | $SED "s/\(NEW|\|SKIP|\|FOUND|\|ADD|\)//g") #"
if [ ! -z "$ERRMSG" ]; then
    log "$MSG_WSM_MODSEC_AGENERR $ERRMSG"
    exit $EXIT_ERR
fi

# NEW| in result (without ADD|) indicates an empty audit log with
# nothing to do - we're done, exiting silently.
if [ "$RESULT" == "NEW|" ]; then exit $EXIT_SUCC; fi

# NEW|ADD| in result indicates a previously empty audit log filled in now,
# we need leave a log line then exit.
if [ "${RESULT:0:8}" == "NEW|ADD|" ]; then
    log "$MSG_WSM_MODSEC_NEWAUDIT $auditlog"
    exit $EXIT_SUCC
fi

# If not NEW| normally the catalog contains last audit log entry
# indicated by FOUND| in result. In this case we're done.
if [ ! -z "`expr "$RESULT" : '.*\(FOUND|\)'`" ]; then exit $EXIT_SUCC; fi

# Otherwise the catalog wasn't updated but completely changed (e.g. rotated)
# and we're in trouble. Maybe the best to (re?)serialize all records
# pointed in the (new) catalog.
RESULT=$({
cat "$catalog" |  while read logentry
do
    # Parsing relative pathname of an audit entry (dirty, TODO!).
    auditentry=$(echo "$logentry" | cut -d ' ' -f 16)
    # Copy corresponding audit entry into serialized auditlog,
    # followed by the catalog line as a marker.
    cat "$AUDITLOGDIR/$auditentry" >>"$auditlog"
    echo "$logentry" >>"$auditlog"
    echo -ne "ADD|"
done
})
# Writing a log entry when succeeded (only one log entry written
# for a new catalog).
if [ ! -z "$RESULT" ]; then log "$MSG_WSM_MODSEC_NEWCAT $catalog"; fi

# That's all, folks :-)

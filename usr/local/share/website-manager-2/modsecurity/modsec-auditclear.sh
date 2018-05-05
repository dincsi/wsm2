#!/bin/bash
#
# Simple script to purge AuditLogDir, the ModSecurity concurrent
# logging event store. Deletes all entries before today.
# Called via /etc/cron.d/wsm2 as www-data by default once daily at 01:00
#
# Part of website-manager-2 package.

AUDIT_HANDLE=1                                          # Set 0 to disable
if [ -d "/var/lib/mod_security/AuditLogDir" ]; then	# wsm2 before 2.6 compatibility
    AUDITLOGDIR="/var/lib/mod_security/AuditLogDir"     # Audit events folder (old)
else							# wsm2 v2.6+
    AUDITLOGDIR="/var/lib/modsecurity/AuditLogDir"      # Audit events folder (new)
fi
DATE="/bin/date"                                        # date command call

# Including headers (if any).
HEADERS="/etc/default/wsm2-modsec-audit"
if [ -r "$HEADERS" ]; then . $HEADERS; fi

# Silent exit on disabled.
if [ "$AUDIT_HANDLE" -eq 0 ]; then exit $EXIT_SUCC; fi

today=$($DATE '+%Y%m%d')
# Enumerating AuditLogDir daily subdirectories.
ls -1 "$AUDITLOGDIR" | while read logdir
do
    # Formal check: conventional logdir name containing 8 digits only.
    if [ "`expr "$logdir" : '^[[:digit:]]\{8\}$'`" -eq 8 ]; then
	# Remove logdirs named on YYYYMMDD convention where YYYYMMDD < today.
	if [ "$logdir" \< "$today" ]; then
	    rm -R  "$AUDITLOGDIR/$logdir"
	fi
    fi
done

# Finished.

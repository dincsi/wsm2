#!/bin/bash
# Simple wrapper script to update ModSecurity core ruleset from Internet.
# Download-only mode, isn't destructive.
# Call periodically e.g. by symlinking from /etc/cron.weekly.
# Part of website-manager-2 package.

DEBIAN_MAIOR="$(cat /etc/debian_version | /usr/bin/cut -c1)"
MODSEC_BRANCH="modsecurity-crs"
MODSEC_CONF="/etc/default/wsm2-modsec-update"
MODSEC_DIR="/etc/apache2/modsecurity"

# Only root allowed to run.
if [ ! $UID -eq 0 ]; then exit 1; fi

# Maximum Debian version is Squeeze.
if [ $DEBIAN_MAIOR -gt 6 ]; then exit 1; fi

# Check rules-updater.pl utility from mod-security-common package.
MODSEC_UPDATER="$MODSEC_DIR/currentversion/rules-updater.pl"
if [ ! -x "$MODSEC_UPDATER" ]; then
    # Try within new directory structure.
    MODSEC_UPDATER="$MODSEC_DIR/currentversion/util/rules-updater.pl"
    # On failure silently giving up.
    if [ ! -x "$MODSEC_UPDATER" ]; then exit 1; fi
fi
# rules-updater.pl identified, call them.
"$MODSEC_UPDATER" -d -c "$MODSEC_CONF" -S$MODSEC_BRANCH >/dev/null
exit $?


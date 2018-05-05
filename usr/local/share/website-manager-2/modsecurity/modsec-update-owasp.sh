#!/bin/bash
# Simple wrapper script to update OWASP ModSecurity core ruleset from Internet.
# Download-only mode, isn't destructive.
# Call periodically e.g. by symlinking from /etc/cron.weekly.
# Part of website-manager-2 package.

BASENAME=$(which basename)	# basename command call
FIND=$(which find)		# find command call
GREP=$(which grep)		# grep command call
HEAD=$(which head)		# head command call
SED=$(which sed)		# sed command call
TAR=$(which tar)		# tar command call
UNZIP=$(which unzip)		# unzip command call
WGET=$(which wget)		# wget command call

DEBIAN_MAIOR="$(cat /etc/debian_version | /usr/bin/cut -c1)"
if [ "$DEBIAN_MAIOR" -ge 8 ]; then # Jessie +
    MODSEC_DIR="/etc/modsecurity/modsecurity-crs"
else # Wheezy
    MODSEC_DIR="/etc/apache2/modsecurity/modsecurity-crs"
fi
MODSEC_TIMEOUT=1
MODSEC_URL="https://github.com/SpiderLabs/owasp-modsecurity-crs/archive/v3.0/master.zip"
MODSEC_USERAGENT="WSM2 ModSecurity CRS Updater"

MSG_MODSEC_EXISTS="Refused to overwrite existing CRS at"
MSG_MODSEC_NEWCRSFOUND="New ModSecurity OWASP CRS found!"
MSG_MODSEC_NEWCRSREADY="New CRS is ready to use at"
MSG_MODSEC_UNTARERROR="Error extracting"
MSG_MODSEC_WGETERROR="Unable to download CRS from"

# Only root allowed to run.
if [ ! $UID -eq 0 ]; then exit 1; fi

# Minimum Debian version is Wheezy.
if [ $DEBIAN_MAIOR -lt 7 ]; then exit 1; fi

# Including config file (if any).
MODSEC_CONF="/etc/default/wsm2-modsec-update-owasp"
if [ -r "$MODSEC_CONF" ]; then . $MODSEC_CONF; fi

# Simply quit if wsm2 isn't configured yet.
if [ ! -d "$MODSEC_DIR" ]; then exit 1; fi

# Getting the last version as a tarball.
MODSEC_TMPFILE="/tmp/modsecurity-crs-owasp-master.zip"
if [ -f "$MODSEC_TMPFILE" ]; then rm "$MODSEC_TMPFILE"; fi
RESULT=$($WGET "$MODSEC_URL" -O "$MODSEC_TMPFILE" --no-check-certificate -U "$MODSEC_USERAGENT" -T "$MODSEC_TIMEOUT" >/dev/null 2>&1; echo $?)
if [ "$RESULT" -ne 0 ]; then
    echo "$MSG_MODSEC_WGETERROR $MODSEC_URL"
    if [ -f "$MODSEC_TMPFILE" ]; then rm "$MODSEC_TMPFILE"; fi
    exit 1
fi

# Check version.
CRSVERLINE=$($UNZIP -p "$MODSEC_TMPFILE" "*/CHANGES" | $GREP -i 'version' | $HEAD -n1)
CRSVER=$(echo "$CRSVERLINE" | $SED "s/.\+ersion\s\+\([.0-9]\+\).*/\1/") #"
if [ -d "$MODSEC_DIR/$CRSVER" ]; then
    echo "$MSG_MODSEC_EXISTS $MODSEC_DIR/$CRSVER"
    if [ -f "$MODSEC_TMPFILE" ]; then rm "$MODSEC_TMPFILE"; fi
    exit 1
fi

# New CRS found!
echo -e "$MSG_MODSEC_NEWCRSFOUND\n$CRSVERLINE"
mkdir "$MODSEC_DIR/$CRSVER"
RESULT=$($UNZIP -q "$MODSEC_TMPFILE" -d "$MODSEC_DIR/$CRSVER"; echo $?)
if [ "$RESULT" -ne 0 ]; then
    echo "$MSG_MODSEC_UNTARERROR $MODSEC_TMPFILE -> $MODSEC_DIR/$CRSVER"
    if [ -f "$MODSEC_TMPFILE" ]; then rm "$MODSEC_TMPFILE"; fi
    exit 1
fi
# Strip the 1st level folder (like tar with --strip-components=1).
pushd $(pwd) >/dev/null; cd "$MODSEC_DIR/$CRSVER"
    STRIPDIR=$(ls -1)
    $FIND "$STRIPDIR" -type d -exec mv {} . \; 2>/dev/null
    $FIND "$STRIPDIR" -type f -exec mv {} . \; 2>/dev/null
    rmdir "$STRIPDIR"
popd >/dev/null
# Harden access rights.
chmod -R g-w,o-rwx "$MODSEC_DIR/$CRSVER"

# ModSecurity CRS rules activation (Jessie +):
# v2+ CRS: symlinking the base rules into the activated_rules folder;
# v3+ CRS: copying the whole ruleset with a minimal patch.
# Note, the ruleset folder tree was changed for CRS v3+!
if [ "$DEBIAN_MAIOR" -ge 8 ]; then
    # CRS v2 - activation by symlinking every single rules
    if [  -d "$MODSEC_DIR/$CRSVER/base_rules" -a -d "$MODSEC_DIR/$CRSVER/activated_rules" ]; then
	for config in $MODSEC_DIR/$CRSVER/base_rules/*.data $MODSEC_DIR/$CRSVER/base_rules/*.conf
	do
    	    if [ ! -L "$MODSEC_DIR/$CRSVER/activated_rules/$($BASENAME "$config")" ]; then
        	ln -s "../base_rules/$($BASENAME "$config")" "$MODSEC_DIR/$CRSVER/activated_rules/$($BASENAME "$config")"
    	    fi
	done
    # CSR v3+ - activation by copying and patching every single rules
    else
	mkdir -m 750 "$MODSEC_DIR/$CRSVER/activated_rules"
	for config in $MODSEC_DIR/$CRSVER/rules/*.data $MODSEC_DIR/$CRSVER/rules/*.conf
	do
    	    if [ ! -f "$MODSEC_DIR/$CRSVER/activated_rules/$($BASENAME "$config")" ]; then
		# Hotfix for https://github.com/SpiderLabs/owasp-modsecurity-crs/issues/651
		cat "$config" | $SED "s/\\([^[:space:]]\\)\\\\\$/\\1 \\\\/g" >"$MODSEC_DIR/$CRSVER/activated_rules/$($BASENAME "$config")"
	    fi
	    chmod -R g-w,o-rwx "$MODSEC_DIR/$CRSVER/activated_rules"
	done
    fi
    # Then activating the main CRS example configuration(s), if any.
    for config in $MODSEC_DIR/$CRSVER/*.example
    do
        if [ ! -L "$MODSEC_DIR/$CRSVER/$($BASENAME "$config" .example)" ]; then
            ln -s "$($BASENAME "$config")" "$MODSEC_DIR/$CRSVER/$($BASENAME "$config" .example)"
        fi
    done
fi

# Cleanup.
if [ -f "$MODSEC_TMPFILE" ]; then rm "$MODSEC_TMPFILE"; fi
# That's all!
echo "$MSG_MODSEC_NEWCRSREADY $MODSEC_DIR/$CRSVER"

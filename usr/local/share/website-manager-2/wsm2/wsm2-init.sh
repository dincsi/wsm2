#!/bin/bash
#
# Cronjob to run for every system start.
# Called from /etc/cron.d/wsm2 @reboot as root.
#
# Part of website-manager-2 package.

# Including headers
MSG_WSM_NOHEADER="Fatal - header file is not found:"
for header in "/etc/default/wsm2" "/etc/default/wsm2-common"
do
    if [ ! -r "$header" ]; then echo -e "$MSG_WSM_NOHEADER $header" >&2; exit 1; fi
    . "$header"
done

# Creating multiuser lock directory for http/https DAV.
if [ ! -d $APACHELOCKDIR ]; then
    mkdir -m 2770 $APACHELOCKDIR 2>&1
    chown $APACHEUSER:$APACHEGROUP $APACHELOCKDIR
    $SETFACL -d -m g::rwX $APACHELOCKDIR
fi

# That's all, folks! :-)

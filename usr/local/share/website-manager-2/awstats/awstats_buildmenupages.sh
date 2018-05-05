#!/bin/bash
#
# Simple script to generate a frameset menu page for AwStats results
# static webpages. Left frame provides a per-month navigation.
# Part of website-manager-2 package.

# Common literals for standalone use - maybe overriden by headers

APACHEADMIN="webadmin"                                  # Linux user for web administration
APACHEADMINGROUP="www-data"                             # Linux group for web administration
AWK="/usr/bin/awk"                                      # awk command call
BASENAME="/usr/bin/basename"                            # basename command call
EXIT_ERR="1"                                            # Error code on failure
FIND="/usr/bin/find"                                    # find command call
GREP="/bin/grep"                                        # grep command call
ICONPATH="/usr/share/awstats/icon"                      # AwStats icon folder
SORT="/usr/bin/sort"                                    # sort command call

# Including header (if any).
HEADER="/etc/default/wsm2-awstats"
if [ -r "$HEADER" ]; then . $HEADER; fi

# Not redefineable literals.
DOCFRAME="document"                             # Document frame name
INDEXPAGE="index.html"                          # Index page filename
MENUFRAME="menu"                                # Menu frame name
MENUPAGE="menu.html"                            # Menu frame filename

# Getting parameters.
if [ -z "$1" -o ! -d "$1" ]; then  echo "Usage: $0 path_to_vhost_stats_rootdir" >&2; exit $EXIT_ERR; fi
ROOT_DIR="$1"; shift
if [ ! -d "$ROOT_DIR" ]; then exit; fi

# Creating icon symlink if absent.
if [ ! -L "$ROOT_DIR/icon" ]; then
    ln -s "$ICONPATH" "$ROOT_DIR/icon"
    chown -h $APACHEADMIN:$APACHEADMINGROUP "$ROOT_DIR/icon"
fi

# Creating empty pages.
rm -f "$ROOT_DIR/$INDEXPAGE"; touch "$ROOT_DIR/$INDEXPAGE"
chmod 640 "$ROOT_DIR/$INDEXPAGE"
chown $APACHEADMIN:$APACHEADMINGROUP "$ROOT_DIR/$INDEXPAGE"
rm -f "$ROOT_DIR/$MENUPAGE"; touch "$ROOT_DIR/$MENUPAGE"
chmod 640 "$ROOT_DIR/$MENUPAGE"
chown $APACHEADMIN:$APACHEADMINGROUP "$ROOT_DIR/$MENUPAGE"

# Generating frameset page.
cat << EOF >> "$ROOT_DIR/$INDEXPAGE"

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Frameset//EN">

<HTML>
    <HEAD>
        <TITLE>Statisztika</TITLE>
        <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-2">
    </HEAD>

    <frameset cols="80,*">
        <frame name="$MENUFRAME" src="$MENUPAGE" frameborder="0" noresize>
        <frame name="$DOCFRAME" frameborder="0" noresize>
    </frameset>
</HTML>
EOF

# Generating menu frame page - header.
cat << EOF >> "$ROOT_DIR/$MENUPAGE"

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">

<HTML>
    <HEAD>
        <TITLE>Menu</TITLE>
        <meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-2">

        <STYLE type="text/css">
        <!--
        p { font: 11px verdana, arial, helvetica, sans-serif; font-weight: bold; }
        a { font: 11px verdana, arial, helvetica, sans-serif; }
        a:link    { color: #0011BB; text-decoration: none; }
        a:visited { color: #0011BB; text-decoration: none; }
        a:hover   { color: #605040; text-decoration: underline; }
        //-->
        </STYLE>
    </HEAD>

    <BODY BGCOLOR="#ffffff" STYLE='margin: 5;' MARGINWIDTH="5" MARGINHEIGHT="5" TOPMARGIN="5" LEFTMARGIN="5">

    <P>&Eacute;v, h&oacute;nap:</P>

EOF

# Generating weblinks - a bit tricky: shortest filename from subfolders
# considering as index page within subfolder.
$FIND "$ROOT_DIR" -type d -exec $BASENAME {} \; | \
    $GREP -vi "$($BASENAME "$ROOT_DIR")" | $SORT | while read TARGETDIR
do
    TARGETFILE=`ls "$ROOT_DIR/$TARGETDIR" | $AWK '{ if (x == 0 || x > length()) { x = length(); y = $0 } } END { print y }'`
    TARGETFILE=$($BASENAME $TARGETFILE)
    echo -n '    <a href="./' >> "$ROOT_DIR/$MENUPAGE"
    echo -n "$TARGETDIR/$TARGETFILE" >> "$ROOT_DIR/$MENUPAGE"
    echo -n '" target="' >> "$ROOT_DIR/$MENUPAGE"
    echo -n $DOCFRAME >> "$ROOT_DIR/$MENUPAGE"
    echo -n '">' >> "$ROOT_DIR/$MENUPAGE"
    echo -n $TARGETDIR >> "$ROOT_DIR/$MENUPAGE"
    echo   '</a><br>' >> "$ROOT_DIR/$MENUPAGE"
done

# Generating footer.
cat << EOF >> "$ROOT_DIR/$MENUPAGE"

    </BODY>
</HTML>
EOF

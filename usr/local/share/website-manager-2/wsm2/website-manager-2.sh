#!/bin/bash
#
# Simple toolkit to manage websites under Apache-2 webserver on Debian.
# Part of website-manager-2 package. Sorry about my terrible English! :-)

# Including headers
MSG_WSM_NOHEADER="Fatal - header file is not found:"
for header in "/etc/default/wsm2" "/etc/default/wsm2-common"
do
    if [ ! -r "$header" ]; then echo -e "$MSG_WSM_NOHEADER $header" >&2; exit 1; fi
    . "$header"
done

#
# Functions
#

# wsm_createweb website [email [cert [webmaster [wmpassword [auditor [aupassword]]]]]
# Creates a static website with DAV management and web statistics generation.

function wsm_createweb {

# Checking components and circumstances.
    if [ ! $UID -eq 0 ]; then log $MSG_WSM_ALL_ROOTNEED; return $EXIT_ERR; fi
    if [ ! -f "$WSMTEMPLATEDIR/$WSMHTTPTEMPLATE.$DEBIAN_MAIOR" -a ! -f "$WSMTEMPLATEDIR/$WSMHTTPTEMPLATE" ]; then
	echo -e "$MSG_WSM_CREATEWEB_NOTEMPLATE $WSMTEMPLATEDIR/$WSMHTTPTEMPLATE" >&2; return $EXIT_ERR; fi
    if [ ! -f "$WSMTEMPLATEDIR/$WSMHTMLPAGE.$DEBIAN_MAIOR" -a ! -f "$WSMTEMPLATEDIR/$WSMHTMLPAGE" ]; then 
	echo -e "$MSG_WSM_CREATEWEB_NOTEMPLATE $WSMTEMPLATEDIR/$WSMHTMLPAGE" >&2; return $EXIT_ERR; fi

    # Website is mandatory and formally checked.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log "$MSG_WSM_CREATEWEB_NOWEBSITE"; return $EXIT_ERR; fi
    if [ ! -z "`echo "$vhost" | $SED "s/$MASKWEB//"`" ]; then log "$MSG_WSM_CREATEWEB_WRONGWEB"; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$vhost" -a -d "$APACHEAUTHDIR/$vhost" ]; then
	local APACHEAUTHDIR="$APACHEAUTHDIR/$vhost"
    fi

    # Site administrator's email is optional, but formally checked.
    local email="$1"; shift
    if [ -z "$email" ]; then email=$DEFAULT_EMAIL; fi
    if [ ! -z "`echo "$email" | $SED "s/$MASKEMAIL//"`" ]; then log "$MSG_WSM_CREATEWEB_WRONGEMAIL"; return $EXIT_ERR; fi

    # Certificate to use or certificate authority responsible for website is optional but formally checked.
    local cert="$1"; shift
    if [ -z "$cert" ]; then cert="$DEFAULT_CERT"; fi
    if [ ! -z "`echo "$cert" | $SED "s/$MASKCERT//"`" ]; then log "$MSG_WSM_CREATEWEB_WRONGERT"; return $EXIT_ERR; fi

    # Webmaster's username is optional, but formally checked.
    local webmaster="$1"; shift
    if [ -z "$webmaster" ]; then webmaster=$DEFAULT_WEBMASTER; fi
    if [ ! -z "`echo "$webmaster" | $SED "s/$MASKUSER//"`" ]; then log "$MSG_WSM_CREATEWEB_WRONGWMUSER"; return $EXIT_ERR; fi

    # Webmaster's password is optional, but formally checked.
    local wmpassword="$1"; shift
    if [ -z "$wmpassword" ]; then wmpassword=`$MAKEPASSWD`; fi
    if [ ! -z "`echo "$wmpassword" | $SED "s/$MASKPASS//"`" ]; then log "$MSG_WSM_CREATEWEB_WRONGWMPWD"; return $EXIT_ERR; fi

    # Auditor's username is optional, but formally checked.
    local auditor="$1"; shift
    if [ -z "$auditor" ]; then auditor=$DEFAULT_AUDITOR; fi
    if [ ! -z "`echo "$auditor" | $SED "s/$MASKUSER//"`" ]; then log "$MSG_WSM_CREATEWEB_WRONGAUUSER"; return $EXIT_ERR; fi

    # Auditor's password is optional, but formally checked.
    local aupassword="$1"; shift
    if [ -z "$aupassword" ]; then aupassword=`$MAKEPASSWD`; fi
    if [ ! -z "`echo "$aupassword" | $SED "s/$MASKPASS//"`" ]; then log "$MSG_WSM_CREATEWEB_WRONGAUPWD"; return $EXIT_ERR; fi

    # Avoid overwriting any existing content.
    if [ -d "$APACHEDOCROOT/$vhost" ]; then log "$MSG_WSM_CREATEWEB_DOCROOTEXIST"; return $EXIT_ERR; fi
    if [ -f "$APACHEVHOSTSDIR/$vhost" ]; then log "$MSG_WSM_CREATEWEB_HTTPCONFEXIST"; return $EXIT_ERR; fi
    if [ -f "$APACHEAUTHDIR/$vhost.user" ]; then log "$MSG_WSM_CREATEWEB_HTTPUSEREXIST"; return $EXIT_ERR; fi
    if [ -f "$APACHEAUTHDIR/$vhost.group" ]; then log "$MSG_WSM_CREATEWEB_HTTPGROUPEXIST"; return $EXIT_ERR; fi

    local TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Creating per-virtualhost authentication folder, if necessary.
#
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$vhost" ]; then
        mkdir -m 755 $APACHEAUTHDIR/$vhost
        log "$APACHEAUTHDIR/$vhost" "$MSG_WSM_CREATEWEB_CREATED"
	# Dirty hack: redefine settings.
	if [ -d "$APACHEAUTHDIR/$vhost" ]; then
	    local APACHEAUTHDIR="$APACHEAUTHDIR/$vhost"
	fi
    else
        log "$APACHEAUTHDIR" "$MSG_WSM_CREATEWEB_EXISTS"
    fi

# Creating web users and groups.
#
    wsm_adduser $vhost $webmaster $wmpassword
    wsm_addgroup $vhost $APACHEVHADMINGROUP
    wsm_addusertogroup $vhost $webmaster $APACHEVHADMINGROUP
    wsm_adduser $vhost $auditor $aupassword
    wsm_addgroup $vhost $APACHEVHSTATSGROUP
    wsm_addusertogroup $vhost $auditor $APACHEVHSTATSGROUP

# Creating web document root and minimal content:
# indexpage, robots file, download, binary, config, download, log, upload directory 
# and stats link.
#
    # Document root.
    if [ ! -d $APACHEDOCROOT/$vhost ]; then
        mkdir -m 2750 $APACHEDOCROOT/$vhost
        chown $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost
        log "$APACHEDOCROOT/$vhost" "$MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEDOCROOT/$vhost" "$MSG_WSM_CREATEWEB_EXISTS"
    fi
    # Index page.
    if [ ! -f $APACHEDOCROOT/$vhost/$DEFAULT_PAGE ]; then
        export TIMESTAMP vhost
        cat $WSMTEMPLATEDIR/$WSMHTMLPAGE | $ENVSUBST > $APACHEDOCROOT/$vhost/$DEFAULT_PAGE
        chmod 640 $APACHEDOCROOT/$vhost/$DEFAULT_PAGE
        chown $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost/$DEFAULT_PAGE
        log "$APACHEDOCROOT/$vhost/$DEFAULT_PAGE" "$MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEDOCROOT/$vhost/$DEFAULT_PAGE" "$MSG_WSM_CREATEWEB_EXISTS"
    fi
    # Robots page.
    if [ ! -f $APACHEDOCROOT/$vhost/$ROBOTS_PAGE ]; then
        export TIMESTAMP vhost
        cat $WSMTEMPLATEDIR/$WSMBOTSFILE | $ENVSUBST > $APACHEDOCROOT/$vhost/$ROBOTS_PAGE
        chmod 640 $APACHEDOCROOT/$vhost/$ROBOTS_PAGE
        chown $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost/$ROBOTS_PAGE
        log "$APACHEDOCROOT/$vhost/$ROBOTS_PAGE" "$MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEDOCROOT/$vhost/$ROBOTS_PAGE" "$MSG_WSM_CREATEWEB_EXISTS"
    fi
    # Webcron file.
    if [ ! -f $APACHEDOCROOT/$vhost/$WEBCRONTAB ]; then
        export TIMESTAMP vhost
        cat $WSMTEMPLATEDIR/$WEBCRONTAB | $ENVSUBST > $APACHEDOCROOT/$vhost/$WEBCRONTAB
        chmod 640 $APACHEDOCROOT/$vhost/$WEBCRONTAB
        chown $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost/$WEBCRONTAB
        log "$APACHEDOCROOT/$vhost/$WEBCRONTAB" "$MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEDOCROOT/$vhost/$WEBCRONTAB" "$MSG_WSM_CREATEWEB_EXISTS"
    fi
    # Download directory
    if [ ! -d $APACHEDOCROOT/$vhost/$APACHEDNLOADDIR ]; then
        mkdir -m 2750 $APACHEDOCROOT/$vhost/$APACHEDNLOADDIR
        chown $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost/$APACHEDNLOADDIR
        log "$APACHEDOCROOT/$vhost/$APACHEDNLOADDIR" "$MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEDOCROOT/$vhost/$APACHEDNLOADDIR" "$MSG_WSM_CREATEWEB_EXISTS"
    fi
    # Upload directory writable by webserver.
    if [ ! -d $APACHEDOCROOT/$vhost/$APACHEUPLOADDIR ]; then
        mkdir -m 2770 $APACHEDOCROOT/$vhost/$APACHEUPLOADDIR
        chown $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost/$APACHEUPLOADDIR
        if [ -x $SETFACL ]; then
            # Force group rw inheritable below this folder.
            $SETFACL -d -m g::rwX $APACHEDOCROOT/$vhost/$APACHEUPLOADDIR
        fi
        log "$APACHEDOCROOT/$vhost/$APACHEUPLOADDIR" "$MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEDOCROOT/$vhost/$APACHEUPLOADDIR" "$MSG_WSM_CREATEWEB_EXISTS"
    fi
    # Directory for symlinked binaries.
    if [ ! -d $APACHEDOCROOT/$vhost/$APACHEVHBINDIR ]; then
        mkdir -m 2750 $APACHEDOCROOT/$vhost/$APACHEVHBINDIR
        chown $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost/$APACHEVHBINDIR
        log "$APACHEDOCROOT/$vhost/$APACHEVHBINDIR" "$MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEDOCROOT/$vhost/$APACHEVHBINDIR" "$MSG_WSM_CREATEWEB_EXISTS"
    fi
    # Directory for configuration files.
    if [ ! -d $APACHEDOCROOT/$vhost/$APACHEVHCONFDIR ]; then
        mkdir -m 2750 $APACHEDOCROOT/$vhost/$APACHEVHCONFDIR
        chown $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost/$APACHEVHCONFDIR
        log "$APACHEDOCROOT/$vhost/$APACHEVHCONFDIR" "$MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEDOCROOT/$vhost/$APACHEVHCONFDIR" "$MSG_WSM_CREATEWEB_EXISTS"
    fi
    # Directory for symlinked logfiles.
    if [ ! -d $APACHEDOCROOT/$vhost/$APACHEVHLOGDIR ]; then
        mkdir -m 2750 $APACHEDOCROOT/$vhost/$APACHEVHLOGDIR
        chown $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost/$APACHEVHLOGDIR
        log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR" "$MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR" "$MSG_WSM_CREATEWEB_EXISTS"
    fi
    # JQuery for PHP logtail.
    if [ ! -L "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/jquery.min.js" ]; then
	ln -s "$WSMTEMPLATEDIR"/jquery-*.min.js "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/jquery.min.js"
	chown -h $APACHEADMIN:$APACHEGROUP "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/jquery.min.js"
	log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/jquery.min.js -> $WSMTEMPLATEDIR/jquery-*.min.js"
    else
	log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/jquery.min.js $MSG_WSM_CREATEWEB_EXISTS"
    fi
    for logfile in $APACHELOGS
    do
	# Native logfiles.
        if [ ! -L "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.log" ]; then
            ln -s "$APACHELOGDIR/$vhost-$logfile.log" "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.log"
            chown -h $APACHEADMIN:$APACHEGROUP "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.log"
            log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.log -> $APACHELOGDIR/$vhost-$logfile.log"
        else
            log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.log $MSG_WSM_CREATEWEB_EXISTS"
        fi
	# Tailed logfiles via PHP.
        if [ ! -L "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php" ]; then
            ln -s "$WSMTEMPLATEDIR/$WSMLOGTAIL" "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php"
            chown -h $APACHEADMIN:$APACHEGROUP "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php"
            log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php -> $WSMTEMPLATEDIR/$WSMLOGTAIL"
        else
            log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php $MSG_WSM_CREATEWEB_EXISTS"
        fi
    done
    for logfile in $PHPLOGS
    do
	# Native logfiles.
        if [ ! -L "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.log" ]; then
            ln -s "$PHPLOGDIR/$vhost-$logfile.log" "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.log"
            chown -h $APACHEADMIN:$APACHEGROUP "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.log"
            log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.log -> $PHPLOGDIR/$vhost-$logfile.log"
        else
            log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile $MSG_WSM_CREATEWEB_EXISTS"
        fi
	# Tailed logfiles via PHP.
        if [ ! -L "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php" ]; then
            ln -s "$WSMTEMPLATEDIR/$WSMLOGTAIL" "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php"
            chown -h $APACHEADMIN:$APACHEGROUP "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php"
            log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php -> $WSMTEMPLATEDIR/$WSMLOGTAIL"
        else
            log "$APACHEDOCROOT/$vhost/$APACHEVHLOGDIR/$logfile.php $MSG_WSM_CREATEWEB_EXISTS"
        fi
    done
    # Prepared symlink for AwStats
    if [ ! -L $APACHEDOCROOT/$vhost/$AWSTATSLINK ]; then
        ln -s $AWSTATSWEBROOT/$vhost $APACHEDOCROOT/$vhost/$AWSTATSLINK
        chown -h $APACHEADMIN:$APACHEGROUP $APACHEDOCROOT/$vhost/$AWSTATSLINK
        log "$APACHEDOCROOT/$vhost/$AWSTATSLINK -> $AWSTATSWEBROOT/$vhost"
    else
        log "$APACHEDOCROOT/$vhost/$AWSTATSLINK $MSG_WSM_CREATEWEB_EXISTS"
    fi

# Certificates configuration.
# If the $cert wasn't specified, a self-signed certificate will be created.
# If the $cert points to a web certificate, that will be used.
# If the $cert points to a CA certificate, that will be used to sign a newly created web certificate.
# If the $cert orders an own, local CA, that will be created and will be used to sign a newly created web certificate.
#
    # Creating own, local CA if ordered. If already exists, the wsm_ca will does nothing silently.
    if [ "$cert" = "$vhost.CA" ]; then wsm_ca "$vhost" "$email"; fi
    # Checking $cert: it points to a CA certificate, a web certificate or invalid?
    if [ -z "$cert" ]; then certfile=""; keyfile=""
    else
	# Finding the certificate itself.
	certfile=$(
	    # Certificate may stored in the Apache authentication folder of this virtualhost,
	    # or in the common SSL certificate storage, and may have .crt or .pem file extension.
	    for folder in "$APACHEAUTHDIR" "$SSLCERTDIR"
	    do
		for extension in pem crt
		do
		    if [ -e "$folder/$cert.$extension" ]; then
			echo "$folder/$cert.$extension"
			break 2 # First match terminates
		    fi
		done
	    done
	)
	# We need a private key for this certificate also.
	if [ -z "$certfile" ]; then keyfile=""
	else
	    keyfile=$(
		# Corresponding private key may stored in the Apache authentication folder of this virtualhost,
		# or in the common SSL key storage, and may have .key extension.
		for folder in "$APACHEAUTHDIR" "$SSLKEYSDIR"
		do
		    for extension in key
		    do
			if [ -e "$folder/$cert.$extension" ]; then
			    echo "$folder/$cert.$extension"
			    break 2 # First match terminates
			fi
		    done
		done
	    )
	fi
    fi
    # Done with $cert (existence) check.
    if [ -z "$certfile" -o -z "$keyfile" ]; then
	# No valid web or CA certificate given: creating a simple, self-signed web certificate.
	# If already exists, wsm_certificate will does nothing silently.
	wsm_certificate "$vhost" "$email"
	# Done, the function call above arranged everything already.
    elif [ ! -z "$($OPENSSL x509 -text -noout -in "$certfile" | $GREP -i "CA:FALSE")" ]; then
	# A web certificate given, let's symlink the $certfile and the $keyfile.
	log "$MSG_WSM_CERT_CERTEXISTING" "$certfile"
	# We need a dummy chainfile also, for simplest Apache https configuration template.
	for extension in "${certfile##*.}" chain
	do
	    # Don't hurts any existing configurations.
	    if [ ! -e "$APACHEAUTHDIR/$vhost.$extension" ]; then
		log $(ln -v -s "$certfile" "$APACHEAUTHDIR/$vhost.$extension")
	    fi
	done
	extension="${keyfile##*.}"
	# Don't hurts any existing keys.
	if [ ! -e "$APACHEAUTHDIR/$vhost.$extension" ]; then
	    log $(ln -v -s "$keyfile" "$APACHEAUTHDIR/$vhost.$extension")
	fi
	# Done with existing web certificate.
    elif [ ! -z "$($OPENSSL x509 -text -noout -in "$certfile" | $GREP -i "CA:TRUE")" ]; then
	# A CA certificate given.
	# Symlinking the CA certificate (various formats) and revocations (if any) for virtualhost.
	CA=$($BASENAME "$certfile")
	CA="${CA%.*}" # drops the file extension
	for extension in crt pem crl der
	do
	    if [ -f "$($DIRNAME $certfile)/$CA.$extension" -a ! -e "$APACHEDOCROOT/$vhost/CA.$extension" ]; then
		log $(ln -v -s "$($DIRNAME $certfile)/$CA.$extension" "$APACHEDOCROOT/$vhost/CA.$extension") #"
		chown -h "$APACHEADMIN:$APACHEGROUP" "$APACHEDOCROOT/$vhost/CA.$extension"
	    fi
	done
	# Creating server certificate, signed by the CA given.
	wsm_certificate "$vhost" "$email" "$cert"
	# Creating a common client certificate, signed by the CA given.
	wsm_client "$vhost" "client@$vhost" "$cert"
	# Symlinking common client certificate (if any) for virtualhost.
	local clientname=$(echo "client@$vhost" | $SED "s/\./_DOT_/g" | $SED "s/@/_AT_/g")
	for extension in p12 #
	do
	    if [ -f "$APACHEAUTHDIR/$vhost.$clientname.$extension" -a ! -f "$APACHEDOCROOT/$vhost/client.$extension" ]; then
		log $(ln -v -s "$APACHEAUTHDIR/$vhost.$clientname.$extension" "$APACHEDOCROOT/$vhost/client.$extension")
		chown -h "$APACHEADMIN:$APACHEGROUP" "$APACHEDOCROOT/$vhost/client.$extension"
	    fi
	done
	# Done with CA-signed certificates.
    else
	# Something failed... As a last resort, a simple, self-signed web certificate will be created.
	# If already exists, wsm_certificate will does nothing silently.
	wsm_certificate "$vhost" "$email"
	# Done, the function call above arranged everything already.
    fi

# Apache webserver configuration.
#
    # Jessie and above needs a .conf extension.
    if [ ! -e "$APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )" ]; then
        export  APACHEADMIN APACHEADMINGROUP APACHEUSER APACHEGROUP \
                APACHEVHADMINGROUP APACHEVHSTATSGROUP \
                APACHEDOCROOT APACHEAUTHDIR APACHELOGDIR \
                APACHEVHBINDIR APACHEVHCONFDIR APACHEVHLOGDIR APACHEDNLOADDIR APACHEUPLOADDIR \
                APACHESSLIP APACHESSLPORT APACHEWEBIP APACHEWEBPORT \
                AUDITLOGGER DEFAULT_HOSTNAME PHPLOGDIR TIMESTAMP \
		SSLCERTDIR SSLKEYSDIR email vhost VERSION WSMTEMPLATEDIR
	if [ -f "$WSMTEMPLATEDIR/$WSMHTTPTEMPLATE.$DEBIAN_MAIOR" ]; then
    	    cat "$WSMTEMPLATEDIR/$WSMHTTPTEMPLATE.$DEBIAN_MAIOR" | $ENVSUBST > "$APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
	else
    	    cat "$WSMTEMPLATEDIR/$WSMHTTPTEMPLATE" | $ENVSUBST > "$APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
	fi
        chown root:root "$APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
	chmod 644 "$APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
        log "$APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" ) $MSG_WSM_CREATEWEB_CREATED"
    else
        log "$APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" ) $MSG_WSM_CREATEWEB_EXISTS"
    fi
    # Activating new virtualhost.
    log "$($APACHEENSITE $vhost)"
    log "$($APACHEDAEMON reload)"

# That's all, folks :-)
    return $EXIT_SUCC
}

# wsm_saveweb website [--noapache] [--noawstats] [--nobins] [--nodocs] [--nologs]
# Save a website - webpages, users, logs, configurations, statistics.

function wsm_saveweb {

# Website is mandatory.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log "$MSG_WSM_ALL_NOWEBSITE"; return $EXIT_ERR; fi

# Parsing optional options.
    local saveapache="Y"
    local saveawstats="Y"
    local savebins="Y"
    local savedocs="Y"
    local savelogs="Y"
    local option="$1"; shift
    while [ ${#option} -gt 0 ];
    do
        case $option in
            --noapache)
                saveapache="N"
                ;;
            --noawstats)
                saveawstats="N"
                ;;
            --nobins)
                savebins="N"
                ;;
            --nodocs)
                savedocs="N"
                ;;
            --nologs)
                savelogs="N"
                ;;
        esac
        option="$1"; shift
    done

    local backupfile=""
    local datetime="`$DATE '+%Y%m%d%H%M%S'`"
    local taroptions=""

# Web content from docroot save.
    if [ $savedocs = "Y" ]; then
        backupfile="`pwd`/`hostname`.$vhost.$datetime.docroot.tar.gz"
        if [ -d $APACHEDOCROOT/$vhost ]; then
            ( cd  $APACHEDOCROOT/$vhost ;
              $TAR 'czf' $backupfile .[^.]* *
            )
            wait
        else
            log "$MSG_WSM_SAVEWEB_NODOCROOT $APACHEDOCROOT/$vhost"
        fi
    fi

# Binaries from binary path save.
    if [ $savebins = "Y" ]; then
        backupfile="`pwd`/`hostname`.$vhost.$datetime.binary.tar.gz"
        if [ -d $APACHEBINROOT/$vhost ]; then
            ( cd  $APACHEBINROOT/$vhost ;
              $TAR 'czf' $backupfile .[^.]* *
            )
            wait
        else
            log "$MSG_WSM_SAVEWEB_NOBINROOT $APACHEBINROOT/$vhost"
        fi
    fi

# Apache configuration, vhost's authentication and certificate files.
    if [ $saveapache = "Y" ]; then
        backupfile="`pwd`/`hostname`.$vhost.$datetime.apache.tar"
        if [ -f "$APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )" ]; then
            if [ ! -f $backupfile ]; then taroptions="c"; else taroptions="r"; fi
            $TAR $taroptions'f' $backupfile $APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" ) 2>/dev/null
        else
            log "$MSG_WSM_SAVEWEB_NOAPACHE $APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
        fi
    	if [ ! -f $backupfile ]; then taroptions="c"; else taroptions="r"; fi
    	$TAR $taroptions'f' $backupfile $APACHEAUTHDIR/$vhost* 2>/dev/null
        if [ -f $backupfile ]; then $GZIP $backupfile; fi
    fi

# Logs.
    if [ $savelogs = "Y" ]; then
        backupfile="`pwd`/`hostname`.$vhost.$datetime.apachelogs.tar.gz"
# Apache logs.
        ( cd $APACHELOGDIR ;
          if [ ! -z "`ls $vhost* 2>/dev/null`" ]; then
              $TAR 'czf' $backupfile $vhost*
          else
              log "$MSG_WSM_SAVEWEB_NOAPACHELOG $APACHELOGDIR/$vhost*"
          fi
        )
        wait
# Optional PHP logs.
        backupfile="`pwd`/`hostname`.$vhost.$datetime.phplogs.tar.gz"
        if [ -d "$PHPLOGDIR" ]; then
            ( cd $PHPLOGDIR ;
              if [ ! -z "`ls $vhost* 2>/dev/null`" ]; then
                  $TAR 'czf' $backupfile $vhost*
              else
                  log "$MSG_WSM_SAVEWEB_NOPHPLOG $PHPLOGDIR/$vhost*"
              fi
            )
        fi
        wait
    fi

# AwStats configuration, results and webpages
    if [ $saveawstats = "Y" ]; then
        backupfile="`pwd`/`hostname`.$vhost.$datetime.awstats.tar"
        if [ -f "$AWSTATSCONFIGDIR/awstats.$vhost.conf" ]; then
            if [ ! -f $backupfile ]; then taroptions="c"; else taroptions="r"; fi
            $TAR $taroptions'f' $backupfile $AWSTATSCONFIGDIR/awstats.$vhost.conf 2>/dev/null
        else
            log "$MSG_WSM_SAVEWEB_NOAWSTATS $AWSTATSCONFIGDIR/awstats.$vhost.conf"
        fi
        if [ ! -z "`ls $AWSTATSCONTDIR/*.$vhost.* 2>/dev/null`" ]; then
            if [ ! -f $backupfile ]; then taroptions="c"; else taroptions="r"; fi
            $TAR $taroptions'f' $backupfile $AWSTATSCONTDIR/*.$vhost.* 2>/dev/null
        else
            log "$MSG_WSM_SAVEWEB_NOAWSTATS $AWSTATSCONTDIR/*.$vhost.*"
        fi
        if [ -d "$AWSTATSWEBROOT/$vhost" ]; then
            if [ ! -f $backupfile ]; then taroptions="c"; else taroptions="r"; fi
            $TAR $taroptions'f' $backupfile $AWSTATSWEBROOT/$vhost 2>/dev/null
        else
            log "$MSG_WSM_SAVEWEB_NOAWSTATS $AWSTATSWEBROOT/$vhost/*"
        fi
        if [ -f $backupfile ]; then $GZIP $backupfile; fi
    fi
}

# wsm_removeweb website [force]
# Remove a website - webpages, binaries, users, logs, configurations, statistics.

function wsm_removeweb {

# Website is mandatory.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log "$MSG_WSM_ALL_NOWEBSITE"; return $EXIT_ERR; fi

# Confirmation request if not forced.
    if [ "$1" != "force" ]; then
        read -s -n1 -p "$MSG_WSM_RMVWEB_CONFIRM"; echo
        if [ "$REPLY" != "y" -a "$REPLY" != "Y" ]; then return $EXIT_ERR; fi
    fi

# Deactivating virtualhost.
    log "$($APACHEDISSITE $vhost)"
    log "$($APACHEDAEMON reload)"

# Removing Apache configuration, certificates, users and groups.
    if [ -f "$APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )" ]; then
        rm -f $APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" ) 2>/dev/null
        log "$MSG_WSM_RMVWEB_REMOVED $APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
    else
        log "$MSG_WSM_RMVWEB_NOAPACHE $APACHEVHOSTSDIR/$vhost$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
    fi
    if [ -d "$APACHEAUTHDIR/$vhost" ]; then
	rm -f $APACHEAUTHDIR/$vhost/* 2>/dev/null
	rmdir "$APACHEAUTHDIR/$vhost" 2>/dev/null
	log "$MSG_WSM_RMVWEB_REMOVED $APACHEAUTHDIR/$vhost"
    else
	log "$MSG_WSM_RMVWEB_NOAPACHEDIR $APACHEAUTHDIR/$vhost"
    fi
    for authfile in $(ls -1 $APACHEAUTHDIR/$vhost.* 2>/dev/null)
    do
	if [ -f "$authfile" -o -L "$authfile" ]; then
    	    rm -f "$authfile" 2>/dev/null
    	    log "$MSG_WSM_RMVWEB_REMOVED $authfile"
	fi
    done

# Removing Apache logs.
    if [ ! -z "`ls $APACHELOGDIR/$vhost* 2>/dev/null`" ]; then
        rm -f $APACHELOGDIR/$vhost* 2>/dev/null
        log "$MSG_WSM_RMVWEB_REMOVED $APACHELOGDIR/$vhost*"
    else
        log "$MSG_WSM_RMVWEB_NOAPACHELOG $APACHELOGDIR/$vhost*"
    fi

# Removing PHP logs.
    if [ ! -z "`ls $PHPLOGDIR/$vhost* 2>/dev/null`" ]; then
        rm -f $PHPLOGDIR/$vhost* 2>/dev/null
        log "$MSG_WSM_RMVWEB_REMOVED $PHPLOGDIR/$vhost*"
    else
        log  "$MSG_WSM_RMVWEB_NOPHPLOG $PHPLOGDIR/$vhost*"
    fi

# Removing AwStats configuration, results and webpages
    if [ -f "$AWSTATSCONFIGDIR/awstats.$vhost.conf" ]; then
        rm -f $AWSTATSCONFIGDIR/awstats.$vhost.conf 2>/dev/null
        log "$MSG_WSM_RMVWEB_REMOVED $AWSTATSCONFIGDIR/awstats.$vhost.conf"
    else
        log "$MSG_WSM_RMVWEB_NOAWSTATS $AWSTATSCONFIGDIR/awstats.$vhost.conf" >&2
    fi
    if [ ! -z "`ls $AWSTATSCONTDIR/*.$vhost.* 2>/dev/null`" ]; then
        rm -f $AWSTATSCONTDIR/*.$vhost.* 2>/dev/null
        log "$MSG_WSM_RMVWEB_REMOVED $AWSTATSCONTDIR/*.$vhost.*"
    else
        log "$MSG_WSM_RMVWEB_NOAWSTATS $AWSTATSCONTDIR/*.$vhost.*"
    fi
    if [ -d "$AWSTATSWEBROOT/$vhost" ]; then
        rm -Rf $AWSTATSWEBROOT/$vhost 2>/dev/null
        log "$MSG_WSM_RMVWEB_REMOVED $AWSTATSWEBROOT/$vhost"
    else
        log "$MSG_WSM_RMVWEB_NOAWSTATS $AWSTATSWEBROOT/$vhost/*"
    fi

# Remove web content from docroot.
    if [ -d $APACHEDOCROOT/$vhost ]; then
        rm -Rf $APACHEDOCROOT/$vhost 2>/dev/null
        log "$MSG_WSM_RMVWEB_REMOVED $APACHEDOCROOT/$vhost"
    else
        log  "$MSG_WSM_RMVWEB_NODOCROOT $APACHEDOCROOT/$vhost"
    fi

# Remove binaries from binary store.
    if [ -d $APACHEBINROOT/$vhost ]; then
        rm -Rf $APACHEBINROOT/$vhost 2>/dev/null
        if [ ! -d $APACHEBINROOT/$vhost ]; then
            log "$MSG_WSM_RMVWEB_REMOVED $APACHEBINROOT/$vhost"
        else
            log "$MSG_WSM_RMVWEB_NOTREMOVED $APACHEBINROOT/$vhost"
        fi
    else
        log "$MSG_WSM_RMVWEB_NOBINROOT $APACHEBINROOT/$vhost"
    fi

    return $EXIT_SUCC
}

# wsm_adduser website username [password]
# Adds a user to website's htpasswd file. If already exist, changes password.
# Finally echoes website, username and password used.

function wsm_adduser {

# Website is mandatory.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log $MSG_WSM_ALL_NOWEBSITE; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$vhost" -a  -d "$APACHEAUTHDIR/$vhost" ]; then
        local APACHEAUTHDIR="$APACHEAUTHDIR/$vhost"
    fi

# User name is mandatory and formally checked.
    local username="$1"; shift
    if [ -z "$username" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi
    if [ ! -z "`echo "$username" | $SED "s/$MASKUSER//"`" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi

# Password is optional, if empty, random password used.
# Password is formally checked also.
    local password="$1"; shift
    if [ -z "$password" ]; then password=`$MAKEPASSWD`; fi
    if [ ! -z "`echo "$password" | $SED "s/$MASKPASS//"`" ]; then log "$MSG_WSM_ADDUSER_WRONGPWD"; return $EXIT_ERR; fi

# Creates user file, if it's not found, then calls htpasswd.
    $TOUCH $APACHEAUTHDIR/$vhost.user
    chown $APACHEADMIN:$APACHEUSER $APACHEAUTHDIR/$vhost.user
    chmod 440 $APACHEAUTHDIR/$vhost.user
    $HTPASSWD -b $APACHEAUTHDIR/$vhost.user $username $password 2>/dev/null
    log $MSG_WSM_ADDUSER_ADDED $vhost $username $password
    return $EXIT_SUCC
}

# wsm_deluser website username
# Deletes given user from website's htpasswd file.
# Deletes group memeberships also, using 
# wsm_listusersgroup and wsm_deluserfromgroup functions.

function wsm_deluser {

# Website is mandatory and must exist.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log $MSG_WSM_ALL_NOWEBSITE; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$vhost" -a  -d "$APACHEAUTHDIR/$vhost" ]; then
        local APACHEAUTHDIR="$APACHEAUTHDIR/$vhost"
    fi
    if [ ! -f "$APACHEAUTHDIR/$vhost.user" ]; then log $MSG_WSM_ALL_NOWEBSITE; return $EXIT_ERR; fi

# User name is mandatory and must exist.
    local username="$1"; shift
    if [ -z "$username" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi
    if [ -z "`cat $APACHEAUTHDIR/$vhost.user | $SED -n "s/$username:/X/p"`" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi

# Removing group memberships.
    local membership=`wsm_listusersgroup $vhost $username`
    local groupname=""
    for groupname in $membership
    do
        wsm_deluserfromgroup $vhost $username $groupname
    done

# Calls htpasswd with -D parameter.
    $HTPASSWD -D $APACHEAUTHDIR/$vhost.user $username 2>/dev/null
    log $MSG_WSM_DELUSER_DELETED $vhost $username
    return $EXIT_SUCC
}

# wsm_addgroup website groupname
# Adds a user's group for website.

function wsm_addgroup {

# Website is mandatory.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log $MSG_WSM_ALL_NOWEBSITE; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$vhost" -a  -d "$APACHEAUTHDIR/$vhost" ]; then
        local APACHEAUTHDIR="$APACHEAUTHDIR/$vhost"
    fi

# Group name is mandatory and formally checked.
    local groupname="$1"; shift
    if [ -z "$groupname" ]; then log $MSG_WSM_ALL_NOGROUP; return $EXIT_ERR; fi
    if [ ! -z "`echo "$groupname" | $SED "s/$MASKGROUP//"`" ]; then log $MSG_WSM_ALL_NOGROUP; return $EXIT_ERR; fi

# Creates group file and group line, if it's not found.
    $TOUCH $APACHEAUTHDIR/$vhost.group
    chown $APACHEADMIN:$APACHEUSER $APACHEAUTHDIR/$vhost.group
    chmod 440 $APACHEAUTHDIR/$vhost.group
    if [ -z "`cat $APACHEAUTHDIR/$vhost.group | $SED -n "s/$groupname:/X/p"`" ]; then 
        echo "$groupname:" >> $APACHEAUTHDIR/$vhost.group
        log $MSG_WSM_ADDGROUP_ADDED $vhost $groupname
    else
        log $MSG_WSM_ADDGROUP_EXISTS $vhost $groupname
    fi
    return $EXIT_SUCC
}

# wsm_delgroup website groupname
# Delete a group line from website's group file.

function wsm_delgroup {

# Website is mandatory.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log $MSG_WSM_ALL_NOWEBSITE; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$vhost" -a  -d "$APACHEAUTHDIR/$vhost" ]; then
        local APACHEAUTHDIR="$APACHEAUTHDIR/$vhost"
    fi

# Group name is mandatory and must exist.
    local groupname="$1"; shift
    if [ -z "$groupname" ]; then log $MSG_WSM_ALL_NOGROUP; return $EXIT_ERR; fi
    if [ -z "`cat $APACHEAUTHDIR/$vhost.group | $SED -n "s/$groupname:/X/p"`" ]; then log $MSG_WSM_ALL_NOGROUP; return $EXIT_ERR; fi

# Delete group line.
    mv $APACHEAUTHDIR/$vhost.group $APACHEAUTHDIR/$vhost.group.bak
    cat $APACHEAUTHDIR/$vhost.group.bak | $GREP -v "$groupname:" >> $APACHEAUTHDIR/$vhost.group
    chown $APACHEADMIN:$APACHEUSER $APACHEAUTHDIR/$vhost.group
    chmod 440 $APACHEAUTHDIR/$vhost.group
    rm $APACHEAUTHDIR/$vhost.group.bak
    log $MSG_WSM_DELGROUP_DELETED $vhost $groupname
    return $EXIT_SUCC
}

# wsm_listusersgroup website username
# Lists all groups containing given user.

function wsm_listusersgroup {

# Website is mandatory.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log $MSG_WSM_ALL_NOWEBSITE; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$vhost" -a  -d "$APACHEAUTHDIR/$vhost" ]; then
        local APACHEAUTHDIR="$APACHEAUTHDIR/$vhost"
    fi

# User name is mandatory and must exist.
    local username="$1"; shift
    if [ -z "$username" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi
    if [ -z "`cat $APACHEAUTHDIR/$vhost.user | $SED -n "s/$username:/X/p"`" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi

# Enumerates group lines and finds username.
    cat $APACHEAUTHDIR/$vhost.group 2>/dev/null | \
    $SED "s/\(:\|,\)/ /g" | \
    $SED -n "s/^\($MASKGROUP\)\(.*\)\($username\)\(.*\)$/\1/p"
    return $EXIT_SUCC
}

# wsm_addusertogroup website user group
# Adds a user to a group of website.

function wsm_addusertogroup {

# Website is mandatory.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log $MSG_WSM_ALL_NOWEBSITE; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$vhost" -a  -d "$APACHEAUTHDIR/$vhost" ]; then
        local APACHEAUTHDIR="$APACHEAUTHDIR/$vhost"
    fi

# User name is mandatory and must exist.
    local username="$1"; shift
    if [ -z "$username" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi
    if [ -z "`cat $APACHEAUTHDIR/$vhost.user | $SED -n "s/$username:/X/p"`" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi

# Group name is mandatory and must exist.
    local groupname="$1"; shift
    if [ -z "$groupname" ]; then log $MSG_WSM_ALL_NOGROUP; return $EXIT_ERR; fi
    if [ -z "`cat $APACHEAUTHDIR/$vhost.group | $SED -n "s/$groupname:/X/p"`" ]; then log $MSG_WSM_ALL_NOGROUP; return $EXIT_ERR; fi

# Gets group line then add user if isn't found.
    mv $APACHEAUTHDIR/$vhost.group $APACHEAUTHDIR/$vhost.group.bak
    cat $APACHEAUTHDIR/$vhost.group.bak | while read line
    do
        if [ ! -z "`echo $line | $SED -n "s/^\($groupname:\)\(.*\)$/\1/p"`" ]; then
            if [ -z "`echo $line | $SED -n "s/^\($groupname\)\(.*\)\(:\|,\)$username\(,\|$\)\(.*\)$/\1/p"`" ]; then
                if [ -z "`echo $line | $SED -n "s/^\(.*\):$/\1/p"`" ]; then
                    echo "$line $username" >> $APACHEAUTHDIR/$vhost.group
                else
                    echo "$line$username" >> $APACHEAUTHDIR/$vhost.group
                fi
                log $MSG_WSM_ADDUSERTOGROUP_ADDED $vhost $username $groupname
            else
                echo $line >> $APACHEAUTHDIR/$vhost.group
                log $MSG_WSM_ADDUSERTOGROUP_EXISTS $vhost $username $groupname
            fi
        else
            echo $line >> $APACHEAUTHDIR/$vhost.group
        fi
    done
    chown $APACHEADMIN:$APACHEUSER $APACHEAUTHDIR/$vhost.group
    chmod 440 $APACHEAUTHDIR/$vhost.group
    rm $APACHEAUTHDIR/$vhost.group.bak
    return $EXIT_SUCC
}

# wsm_deluserfromgroup website user group
# Delete given website user from the given group.

function wsm_deluserfromgroup {

# Website is mandatory.
    local vhost="$1"; shift
    if [ -z "$vhost" ]; then log $MSG_WSM_ALL_NOWEBSITE; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$vhost" -a  -d "$APACHEAUTHDIR/$vhost" ]; then
        local APACHEAUTHDIR="$APACHEAUTHDIR/$vhost"
    fi

# User name is mandatory and must exist.
    local username="$1"; shift
    if [ -z "$username" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi
    if [ -z "`cat $APACHEAUTHDIR/$vhost.user | $SED -n "s/$username:/X/p"`" ]; then log $MSG_WSM_ALL_NOUSER; return $EXIT_ERR; fi

# Group name is mandatory and must exist.
    local groupname="$1"; shift
    if [ -z "$groupname" ]; then log $MSG_WSM_ALL_NOGROUP; return $EXIT_ERR; fi
    if [ -z "`cat $APACHEAUTHDIR/$vhost.group | $SED -n "s/$groupname:/X/p"`" ]; then log $MSG_WSM_ALL_NOGROUP; return $EXIT_ERR; fi

# Gets group lines then removes user if exist.
    mv $APACHEAUTHDIR/$vhost.group $APACHEAUTHDIR/$vhost.group.bak
    cat $APACHEAUTHDIR/$vhost.group.bak | while read line
    do
        if [ ! -z "`echo $line | $SED -n "s/^\($groupname:\)\(.*\)$/\1/p"`" ]; then
            echo $line | $SED "s/\( \|:\)$username\( \|$\)/\1\2/" | \
                 $SED "s/: /:/" | $SED "s/  / /" | $SED "s/ $//" >> $APACHEAUTHDIR/$vhost.group
        else
            echo $line >> $APACHEAUTHDIR/$vhost.group
        fi
    done
    chown $APACHEADMIN:$APACHEUSER $APACHEAUTHDIR/$vhost.group
    chmod 440 $APACHEAUTHDIR/$vhost.group
    rm $APACHEAUTHDIR/$vhost.group.bak
    log $MSG_WSM_DELUSERFROMGROUP_DELETED $vhost $username $groupname
    return $EXIT_SUCC
}

# wsm_ca [ fully_qualified_hostname [ email ]]
# Initialize a minimal, local web certificate authority (CA) for a website, with self-signed local
# CA certificate, a text database and a revocation list. Don't hurts an existing CA.
# By default uses the /etc/apache2/auth.d/fully_qualified_hostname folder as own storage.
#
function wsm_ca {

    # Optional fully qualified hostname or IP address defaults to default hostname.
    local FQHN=${1:-$DEFAULT_HOSTNAME}; shift
    if [ ! -z "$(echo "$FQHN" | $SED "s/$MASKWEB//")" ]; then log "$MSG_WSM_CA_WRONGWEB"; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$FQHN" -a -d "$APACHEAUTHDIR/$FQHN" ]; then
	local APACHEAUTHDIR="$APACHEAUTHDIR/$FQHN"
    fi

    # Optional email address responsible for certificate.
    local email=${1:-$DEFAULT_EMAIL}; shift
    if [ ! -z "`echo "$email" | $SED "s/$MASKEMAIL//"`" ]; then log "$MSG_WSM_CA_WRONGEMAIL"; return $EXIT_ERR; fi

    # Creating CA private key.
    if [ ! -f "$APACHEAUTHDIR/$FQHN.CA.key" ]; then
	$OPENSSL genrsa -out "$APACHEAUTHDIR/$FQHN.CA.key" 4096 2>/dev/null
	if [ -f "$APACHEAUTHDIR/$FQHN.CA.key" ]; then
	    chmod 600 "$APACHEAUTHDIR/$FQHN.CA.key"
	    log "$MSG_WSM_CA_KEYOK $APACHEAUTHDIR/$FQHN.CA.key"
	else
	    log "$MSG_WSM_CA_KEYFAILED $APACHEAUTHDIR/$FQHN.CA.key"
	    return $EXIT_ERR
	fi
    fi

    # Creating configuration for certificate request.
    if [ ! -f "$APACHEAUTHDIR/$FQHN.CA.req" ]; then
	# Getting geolocation parameters via external webservice.
   	geoparams=$(wsm_geolocate $FQHN | $TAIL -n1)
	# Building configuration.
        ca_countryname=$(echo $geoparams | $CUT -d ',' -f2)
        ca_stateorprovince=$(echo $geoparams | $CUT -d ',' -f3)
        ca_localityname=$(echo $geoparams | $CUT -d ',' -f4)
        ca_org="CA.$FQHN"
	ca_orgunit="Certificate Authority"
        ca_cn="CA.$FQHN"
	ca_email="$email"
	export ca_countryname ca_stateorprovince ca_localityname ca_org ca_orgunit ca_cn ca_email \
	       APACHEAUTHDIR FQHN
	cat $WSMTEMPLATEDIR/$WSMREQCATEMPLATE | $ENVSUBST > "$APACHEAUTHDIR/$FQHN.CA.req"
	log "$MSG_WSM_CA_CONFOK $APACHEAUTHDIR/$FQHN.CA.req"
    fi
    # Creating configuration for certificate authority.
    if [ ! -f "$APACHEAUTHDIR/$FQHN.CA.cnf" ]; then
	export APACHEAUTHDIR FQHN SSLCERTDAYS SSLCRLDAYS
	cat $WSMTEMPLATEDIR/$WSMSGNCATEMPLATE | $ENVSUBST > "$APACHEAUTHDIR/$FQHN.CA.cnf"
	log "$MSG_WSM_CA_CONFOK $APACHEAUTHDIR/$FQHN.CA.cnf"
    fi
    # Creating and self-signing CA certificate.
    if [ ! -f "$APACHEAUTHDIR/$FQHN.CA.pem" ]; then
	$OPENSSL req -new \
	         -config "$APACHEAUTHDIR/$FQHN.CA.req" \
	         -key "$APACHEAUTHDIR/$FQHN.CA.key" -sha256 | \
	tee "$APACHEAUTHDIR/$FQHN.CA.csr" | \
	$OPENSSL x509 -req -days $SSLCADAYS -set_serial 01 \
	         -extfile "$APACHEAUTHDIR/$FQHN.CA.cnf" \
	         -signkey "$APACHEAUTHDIR/$FQHN.CA.key" -sha256 \
	         -out "$APACHEAUTHDIR/$FQHN.CA.pem" \
	         2>/dev/null
	# Check certificate, symlink as CRT and convert to DER format also.
	if [ -f "$APACHEAUTHDIR/$FQHN.CA.pem" -a -s "$APACHEAUTHDIR/$FQHN.CA.pem" ]; then
	    log "$MSG_WSM_CA_CERTOK $APACHEAUTHDIR/$FQHN.CA.pem"
	    if [ ! -r "$APACHEAUTHDIR/$FQHN.CA.crt" ]; then
		ln -s "$FQHN.CA.pem" "$APACHEAUTHDIR/$FQHN.CA.crt"
		log "$APACHEAUTHDIR/$FQHN.CA.crt -> $APACHEAUTHDIR/$FQHN.CA.pem"
	    fi
	    $OPENSSL x509 -outform DER \
	             -in  "$APACHEAUTHDIR/$FQHN.CA.pem" \
	             -out "$APACHEAUTHDIR/$FQHN.CA.der" \
	             2>/dev/null
	    log "$MSG_WSM_CA_CERTOK $APACHEAUTHDIR/$FQHN.CA.der"
	    # Initialize CA administration files:
	    # next serial counter, index database.
	    if [ ! -r "$APACHEAUTHDIR/$FQHN.CA.ser" ]; then
		echo "02" >"$APACHEAUTHDIR/$FQHN.CA.ser"
	    fi
	    touch "$APACHEAUTHDIR/$FQHN.CA.idx"
	    # Generating an empty certificate revocation list (CRL).
	    if [ ! -r "$APACHEAUTHDIR/$FQHN.CA.crl" ]; then
		$OPENSSL ca -gencrl \
	                 -config "$APACHEAUTHDIR/$FQHN.CA.cnf" \
		         -out "$APACHEAUTHDIR/$FQHN.CA.crl"
		# Check the CRL.
		if [ -f "$APACHEAUTHDIR/$FQHN.CA.crl" -a -s "$APACHEAUTHDIR/$FQHN.CA.crl" ]; then
		    log "$MSG_WSM_CA_REVOK $APACHEAUTHDIR/$FQHN.CA.crl"
		else
		    log "$MSG_WSM_CA_REVFAILED $APACHEAUTHDIR/$FQHN.CA.crl"
		fi
	    fi
	else
	    log "$MSG_WSM_CA_CERTFAILED $APACHEAUTHDIR/$FQHN.CA.pem"
	    return $EXIT_ERR
	fi
    fi
    return
}

# wsm_certificate  fully_qualified_hostname [[ email ] CA_to_use ]
# Generates an SSL server certificate for a website specified by FQHN,
# signed by local or global CA given, or self-signed if CA isn't available.
# If the certificate already exists, tries to refresh it (regenerate using
# the existing configuration).
#
function wsm_certificate {
    local geoparams

    # Mandatory fully qualified hostname.
    local FQHN=${1:-''}; shift
    if [ ! -z "$(echo "$FQHN" | $SED "s/$MASKWEB//")" ]; then log "$MSG_WSM_CERT_WRONGWEB"; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$FQHN" -a -d "$APACHEAUTHDIR/$FQHN" ]; then
	local APACHEAUTHDIR="$APACHEAUTHDIR/$FQHN"
    fi

    # Optional email address responsible for certificate.
    local email=${1:-$DEFAULT_EMAIL}; shift
    if [ ! -z "`echo "$email" | $SED "s/$MASKEMAIL//"`" ]; then log "$MSG_WSM_CERT_WRONGEMAIL"; return $EXIT_ERR; fi

    # Optional CA certificate f(ilename W/O extension), defaults to own local CA certificate (f any).
    local CA=${1:-$FQHN.CA}; shift
    if [ ! -z "`echo "$CA" | $SED "s/$MASKCERT//"`" ]; then log "$MSG_WSM_CERT_WRONGCERT"; return $EXIT_ERR; fi

    # Creating private key for website (server side) certificate.
    # When is already created, we don't change.
    if [ ! -f "$APACHEAUTHDIR/$FQHN.key" ]; then
	# Certificate without key considered orphan and will be deleted.
	if [ -f "$APACHEAUTHDIR/$FQHN.pem" ]; then
	    rm "$APACHEAUTHDIR/$FQHN.pem" 2>/dev/null
	    log "$MSG_WSM_CERT_ORPHANCERT $APACHEAUTHDIR/$FQHN.pem"
	fi
	# Generating RSA key.
	$OPENSSL genrsa -out "$APACHEAUTHDIR/$FQHN.key" 2048 2>/dev/null
	result=$?
	if [ -f "$APACHEAUTHDIR/$FQHN.key" ]; then
	    chmod 600 "$APACHEAUTHDIR/$FQHN.key"
	    log "$MSG_WSM_CERT_KEYOK $APACHEAUTHDIR/$FQHN.key (genrsa:$result)"
	else
	    log "$MSG_WSM_CERT_KEYFAILED $APACHEAUTHDIR/$FQHN.key (genrsa:$result)"
	    return $EXIT_ERR
	fi
    fi

    # If an old certificate for website exists, and we have a valid CA, the certificate
    # will be revoked; then will be deleted anyway.
    wsm_revoke "$FQHN" "$FQHN" "$CA"
    for extension in chain crl csr pem
    do
	rm "$APACHEAUTHDIR/$FQHN.$extension" 2>/dev/null
    done

    # Creating website certificate request.
    if [ ! -e "$APACHEAUTHDIR/$FQHN.pem" -o ! -s "$APACHEAUTHDIR/$FQHN.pem" ]; then
        # Creating configuration for certificate request.
	if [ ! -e "$APACHEAUTHDIR/$FQHN.cnf" -o ! -s "$APACHEAUTHDIR/$FQHN.cnf" ]; then
	# Getting geolocation parameters via external webservice.
	    geoparams=${geoparams:-$(wsm_geolocate $FQHN | $TAIL -n1)}
	    # Building configuration.
    	    cert_countryname=$(echo -e "$geoparams" | $CUT -d ',' -f2)
    	    cert_stateorprovince=$(echo -e "$geoparams" | $CUT -d ',' -f3)
    	    cert_localityname=$(echo -e "$geoparams" | $CUT -d ',' -f4)
    	    cert_org="$FQHN"
	    cert_orgunit="Web Services"
    	    cert_cn="$FQHN"
	    cert_email="$email"
	    export cert_countryname cert_stateorprovince cert_localityname \
	           cert_org cert_orgunit cert_cn cert_email FQHN
	    cat $WSMTEMPLATEDIR/$WSMREQSRVTEMPLATE | $ENVSUBST > "$APACHEAUTHDIR/$FQHN.cnf"
	    log "$MSG_WSM_CERT_CONFOK $APACHEAUTHDIR/$FQHN.cnf"
	fi
	# Generating certificate request.
	$OPENSSL req -new \
	         -config "$APACHEAUTHDIR/$FQHN.cnf" \
	         -key "$APACHEAUTHDIR/$FQHN.key" -sha256 \
	         -out "$APACHEAUTHDIR/$FQHN.csr" \
	         2>/dev/null
	result=$?
	# Check generated request, giving up on failure.
	if [ ! -e "$APACHEAUTHDIR/$FQHN.csr" -o ! -s "$APACHEAUTHDIR/$FQHN.csr" ]; then
	    log "$MSG_WSM_CERT_REQFAILED $APACHEAUTHDIR/$FQHN.csr (req:$result)"
	    return $EXIT_ERR
	fi

	# Try signing webserver certificate request if the CA given.
	if [ ! -z "$CA" ]; then
	    result="$(wsm_sign -s "$FQHN" "$APACHEAUTHDIR/$FQHN.csr" "$CA")"
	    # On success make some settings.
	    if [ -e "$APACHEAUTHDIR/$FQHN.pem" -a -s "$APACHEAUTHDIR/$FQHN.pem" ]; then
		# Getting parameters of CA used.
		set -- $result; CAcert=$1; CAkey=$2; CAconf=$3; CArev=$4
		# Chain file points to CA's certificate.
		ln -s "$CAcert" $APACHEAUTHDIR/$FQHN.chain 2>/dev/null
		# Revoke list points to the CA's revoke list (if any).
		if [ ! -z "$CArev" -a -e "$CArev" ]; then
		    ln -s "$CArev" $APACHEAUTHDIR/$FQHN.crl 2>/dev/null
		fi
	    fi
	fi
	# On failure or lack of CA, the webserver certificate will be self-signed.
	if [ ! -e "$APACHEAUTHDIR/$FQHN.pem" -o ! -s "$APACHEAUTHDIR/$FQHN.pem" ]; then
	    log "$MSG_WSM_CERT_CASELF"
	    $OPENSSL x509 -req -days $SSLCERTDAYS \
	             -extfile "$WSMTEMPLATEDIR/$WSMSGNSELFCONF" \
	             -in "$APACHEAUTHDIR/$FQHN.csr" \
	             -signkey "$APACHEAUTHDIR/$FQHN.key" \
	             -out "$APACHEAUTHDIR/$FQHN.pem" \
	             2>/dev/null
	    result=$?
	    # Check certificate.
	    if [ -e "$APACHEAUTHDIR/$FQHN.pem" -a -s "$APACHEAUTHDIR/$FQHN.pem" ]; then
		log "$MSG_WSM_CERT_CERTOK $APACHEAUTHDIR/$FQHN.pem (x509:$result)"
		# Chain file points to itself.
		ln -s $APACHEAUTHDIR/$FQHN.pem $APACHEAUTHDIR/$FQHN.chain 2>/dev/null
	    else
		# Failed - giving up.
		log "$MSG_WSM_CERT_CERTFAILED $APACHEAUTHDIR/$FQHN.pem (x509:$result)"
		return $EXIT_ERR
	    fi
	fi
    fi # Done with server certificate.
    return
}

# wsm_client fully_qualified_hostname client_email [ CA_to_use ]
# Generates an SSL client certificate package for a website specified by FQHN,
# signed by local or global CA given, with client's email in subject.
# If the certificate already exists, tries to refresh it (regenerate using
# the existing configuration).
#
function wsm_client {
    local geoparams

    # Mandatory fully qualified hostname.
    local FQHN=${1:-''}; shift
    if [ -z "$FQHN" -o ! -z "$(echo "$FQHN" | $SED "s/$MASKWEB//")" ]; then log "$MSG_WSM_CLI_WRONGWEB"; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$FQHN" -a -d "$APACHEAUTHDIR/$FQHN" ]; then
	local APACHEAUTHDIR="$APACHEAUTHDIR/$FQHN"
    fi

    # Mandatory email address, will be the subject of the client certificate.
    local email=${1:-''}; shift
    if [ -z "$email" -o ! -z "`echo "$email" | $SED "s/$MASKEMAIL//"`" ]; then log "$MSG_WSM_CLI_WRONGEMAIL"; return $EXIT_ERR; fi
    local clientname=$(echo $email | $SED "s/\./_DOT_/g" | $SED "s/@/_AT_/g")

    # Optional CA certificate f(ilename W/O extension), defaults to own local CA certificate (f any).
    local CA=${1:-$FQHN.CA}; shift
    if [ ! -z "`echo "$CA" | $SED "s/$MASKCERT//"`" ]; then log "$MSG_WSM_CLI_WRONGCERT"; return $EXIT_ERR; fi

    # Creating private key for a common client certificate.
    # When is already created, we don't change.
    if [ ! -f "$APACHEAUTHDIR/$FQHN.$clientname.key" ]; then
	# Certificate without key considered orphan and will be deleted.
	if [ -f "$APACHEAUTHDIR/$FQHN.$clientname.pem" ]; then
	    rm "$APACHEAUTHDIR/$FQHN.$clientname.pem" 2>/dev/null
	    log "$MSG_WSM_CLI_ORPHANCERT $APACHEAUTHDIR/$FQHN.$clientname.pem"
	fi
	# Generating RSA key.
	$OPENSSL genrsa -out "$APACHEAUTHDIR/$FQHN.$clientname.key" 2048 2>/dev/null
	result=$?
	if [ -f "$APACHEAUTHDIR/$FQHN.$clientname.key" -a -s "$APACHEAUTHDIR/$FQHN.$clientname.key" ]; then
	    chmod 600 "$APACHEAUTHDIR/$FQHN.$clientname.key"
	    log "$MSG_WSM_CLI_KEYOK $APACHEAUTHDIR/$FQHN.$clientname.key (genrsa:$result)"
	else
	    log "$MSG_WSM_CLI_KEYFAILED $APACHEAUTHDIR/$FQHN.$clientname.key (genrsa:$result)"
	    return $EXIT_ERR
	fi
    fi

    # If an old certificate for this client exists, and we have a valid CA, the certificate
    # will be revoked; then will be deleted anyway.
    wsm_revoke "$FQHN" "$email" "$CA"
    for extension in csr pem p12
    do
	rm "$APACHEAUTHDIR/$FQHN.$clientname.$extension" 2>/dev/null
    done

    # Creating the client certificate request.
    if [ ! -f "$APACHEAUTHDIR/$FQHN.$clientname.pem" ]; then
    	# Creating configuration for certificate request.
	if [ ! -f "$APACHEAUTHDIR/$FQHN.$clientname.cnf" ]; then
	# Getting geolocation parameters via external webservice.
	    geoparams=${geoparams:-$(wsm_geolocate $FQHN | $TAIL -n1)}
	    # Building configuration.
    	    cert_countryname=$(echo -e "$geoparams" | $CUT -d ',' -f2)
    	    cert_stateorprovince=$(echo -e "$geoparams" |  $CUT -d ',' -f3)
    	    cert_localityname=$(echo -e "$geoparams" | $CUT -d ',' -f4)
    	    cert_org="$FQHN"
	    cert_orgunit="Client Services"
    	    cert_cn="$email"
	    cert_email="$DEFAULT_EMAIL"
	    export cert_countryname cert_stateorprovince cert_localityname \
	           cert_org cert_orgunit cert_cn cert_email
	    cat $WSMTEMPLATEDIR/$WSMREQCLITEMPLATE | $ENVSUBST > "$APACHEAUTHDIR/$FQHN.$clientname.cnf"
	    log "$MSG_WSM_CLI_CONFOK $APACHEAUTHDIR/$FQHN.$clientname.cnf"
	fi
	# Generating certificate request.
	$OPENSSL req -new \
		     -config "$APACHEAUTHDIR/$FQHN.$clientname.cnf" \
	    	     -key "$APACHEAUTHDIR/$FQHN.$clientname.key" -sha256 \
	    	     -out "$APACHEAUTHDIR/$FQHN.$clientname.csr" \
	             2>/dev/null
	result=$?
	# Check generated request, giving up on failure.
	if [ ! -e "$APACHEAUTHDIR/$FQHN.$clientname.csr" -o ! -s "$APACHEAUTHDIR/$FQHN.$clientname.csr" ]; then
	    log "$MSG_WSM_CERT_REQFAILED $APACHEAUTHDIR/$FQHN.$clientname.csr (req:$result)"
	    return $EXIT_ERR
	fi

	# Try signing the client certificate request with CA given.
	result="$(wsm_sign -c "$FQHN" "$APACHEAUTHDIR/$FQHN.$clientname.csr" "$CA")"
	# On failure giving up.
	if [ ! -e "$APACHEAUTHDIR/$FQHN.$clientname.pem" -o ! -s "$APACHEAUTHDIR/$FQHN.$clientname.pem" ]; then
	    return $EXIT_ERR
	# On success make some settings.
	else
	    # Getting parameters of CA used.
	    set -- $result; CAcert=$1; CAkey=$2; CAconf=$3; CArev=$4
	    # Creating PKCS12 package with a random export passphrase.
	    passphrase=$($MAKEPASSWD)
	    echo -en "\n\n" | \
	    $OPENSSL pkcs12 -export -chain \
	    	            -passin pass:'' -passout "pass:$passphrase" \
	    	            -name "$email" \
	    	            -caname "$CA" -CAfile "$CAcert" \
	    	            -in "$APACHEAUTHDIR/$FQHN.$clientname.pem" \
	    	            -inkey "$APACHEAUTHDIR/$FQHN.$clientname.key" \
	    	            -out "$APACHEAUTHDIR/$FQHN.$clientname.p12" \
	    	            2>/dev/null
	    result=$?
	    if [ -e "$APACHEAUTHDIR/$FQHN.$clientname.p12" -a -s "$APACHEAUTHDIR/$FQHN.$clientname.p12" ]; then
		log "$MSG_WSM_CLI_CERTOK $APACHEAUTHDIR/$FQHN.$clientname.p12 ($passphrase)"
	    else
		# Failed - giving up.
		log "$MSG_WSM_CLI_CERTFAILED $APACHEAUTHDIR/$FQHN.$clientname.p12 (pkcs12:$result)"
		return $EXIT_ERR
	    fi
	fi
    fi
    return
}

# wsm_revoke fully_qualified_hostname [ certificate [ CA_to_use ]]
# Revokes an SSL (server or client) certificate for a website specified by FQHN,
# using local or global CA given. Regenerates the certificate revoke list also.
# Specially, if you omit the cretificate, only the CRL will be refreshed.
#
function wsm_revoke {

    # Mandatory fully qualified hostname.
    local FQHN=${1:-''}; shift
    if [ -z "$FQHN" -o ! -z "$(echo "$FQHN" | $SED "s/$MASKWEB//")" ]; then log "$MSG_WSM_REV_WRONGWEB"; return $EXIT_ERR; fi
    # Dirty hack: using per-virtualhost authentication folder if exists.
    if [ "$($BASENAME "$APACHEAUTHDIR")" != "$FQHN" -a -d "$APACHEAUTHDIR/$FQHN" ]; then
	local APACHEAUTHDIR="$APACHEAUTHDIR/$FQHN"
    fi

    # Optional certificate to revoke (filename W/O extension).
    local cert=${1:-''}; shift
    if [ ! -z "$(echo $cert | $GREP '@')" ] ; then # client certificate name convention's hack
	cert=$FQHN.$(echo $cert | $SED "s/\./_DOT_/g" | $SED "s/@/_AT_/g"); fi
    if [ ! -z "$(echo "$cert" | $SED "s/$MASKCERT//")" ]; then log "$MSG_WSM_REV_WRONGCERT"; return $EXIT_ERR; fi

    # Optional CA certificate to use to sign. Defaults to FQHN's own CA certificate (if any).
    local CA=${1:-$FQHN.CA}; shift
    if [ ! -z "`echo "$CA" | $SED "s/$MASKCERT//"`" ]; then log "$MSG_WSM_REV_WRONGCACERT"; return $EXIT_ERR; fi
    # Verifying CA, locating its OpenSSL CA configuration (CAconf)
    # and certificate revocation list (CArev, if any).
    local CAcert=""
    local CAkey=""
    local CAconf=""
    local CArev=""
    # Is a local (website) CA (subfoldered configuration)?
    if [ -r "$APACHEAUTHDIR/${CA%'.CA'}/$CA.key" -a -r "$APACHEAUTHDIR/${CA%'.CA'}/$CA.pem" ]; then
	CAcert="$APACHEAUTHDIR/${CA%'.CA'}/$CA.pem"
	CAkey="$APACHEAUTHDIR/${CA%'.CA'}/$CA.key"
	log "$MSG_WSM_REV_CALOCAL $APACHEAUTHDIR/${CA%'.CA'}/$CA"
	# Check configuration according to the wsm2 policy.
	if [ -r "$APACHEAUTHDIR/${CA%'.CA'}/$CA.cnf" ]; then CAconf="$APACHEAUTHDIR/${CA%'.CA'}/$CA.cnf"; fi
	if [ -r "$APACHEAUTHDIR/${CA%'.CA'}/$CA.crl" ]; then CArev="$APACHEAUTHDIR/${CA%'.CA'}/$CA.crl"; fi
    # Again, is a local (website) CA (traditional configuration)?
    elif [ -r "$APACHEAUTHDIR/$CA.key" -a -r "$APACHEAUTHDIR/$CA.pem" ]; then
	CAcert="$APACHEAUTHDIR/$CA.pem"
	CAkey="$APACHEAUTHDIR/$CA.key"
	log "$MSG_WSM_REV_CALOCAL $APACHEAUTHDIR/$CA"
	# Check configuration according to the wsm2 policy.
	if [ -r "$APACHEAUTHDIR/$CA.cnf" ]; then CAconf="$APACHEAUTHDIR/$CA.cnf"; fi
	if [ -r "$APACHEAUTHDIR/$CA.crl" ]; then CArev="$APACHEAUTHDIR/$CA.crl"; fi
    # Is a CA globally (system-wide) installed?
    elif [ -r "$SSLKEYSDIR/$CA.key" -a -r "$SSLCERTDIR/$CA.pem" ]; then
	CAcert="$SSLCERTDIR/$CA.pem"
	CAkey="$SSLKEYSDIR/$CA.key"
	log "$MSG_WSM_REV_CAGLOBAL $CA"
	# Where is its configuration? First hit wins.
	for folder in "$SSLCONFDIR/$CA" "$SSLCONFDIR" "$APACHEAUTHDIR/$CA" "$APACHEAUTHDIR"
	do
	    if [ -z "$CAconf" -a  -r "$folder/$CA.cnf" ]; then CAconf="$folder/$CA.cnf"; fi
	    if [ -z "$CAconf" -a  -r "$folder/$CA.crl" ]; then CArev="$folder/$CA.crl"; fi
	done
	# System-wide OpenSSL configuration is the last refuge :-).
	if [ -z "$CAconf" -a  -r "$SSLCONF" ]; then CAconf="$SSLCONF"; fi
    fi
    # Giving up if no CA or isn't able to sign.
    if [ -z "$CAcert" -o -z "$CAkey" -o -z "$CAconf" -o \
         -z "$($OPENSSL x509 -text -noout -in "$CAcert" 2>/dev/null | $GREP -i "CA:TRUE")" ]; then
	log "$MSG_WSM_REV_NOCA $CA"
	return $EXIT_ERR
    fi
    # We have a suitable CA here.

    # Revoking the certificate given.
    local result=0
    if [ ! -z "$cert" ]; then
	if [ ! -e "$APACHEAUTHDIR/$cert.pem" ]; then
	    # Report non-existing revocation requests.
	    log "$MSG_WSM_REV_NOCERT $APACHEAUTHDIR/$cert.pem"
	    result=1
	else
	    $OPENSSL ca -revoke "$APACHEAUTHDIR/$cert.pem" \
	                -config "$CAconf" \
	    	        -crl_reason superseded \
		        -updatedb \
	                2>/dev/null
	    result=$?
	    # Report the success or failure.
	    if [ $result -eq 0 ]; then
		log "$MSG_WSM_REV_REVOK $cert (ca:$result)"
	    else
		log "$MSG_WSM_REV_REVFAILED $cert (ca:$result)"
	    fi
	fi
    fi

    # Regenerates the existing certificate revocation list (CRL) if necessary.
    if [ $result -eq 0 -a -e "$CArev" ]; then
	$OPENSSL ca -gencrl \
                    -config "$CAconf" \
	            -out "$CArev" \
	            2>/dev/null
	result=$?
	# Check the CRL.
	if [ "$result" -eq 0 -a -f "$CArev" -a -s "$CArev" ]; then
	    log "$MSG_WSM_REV_REVLISTOK $CArev"
	else
	    log "$MSG_WSM_REV_REVLISTFAILED $CArev"
	fi
    fi
    return
}

# wsm_sign [ -s | -c ] fully_qualified_hostname pathname_for_csr [ CA ]
# Signing a server/client certificate request according to FQHN by CA given.
# Warning: unusable for self-signed certificates!
function wsm_sign {

    # Optional options: -s for server, -c for client (default).
    local CSRtype=""
    while [ "$1" == "-s" -o "$1" == "-c" ]
    do
	if [ "$1" == "-s" ]; then CSRtype="server"; fi
	if [ "$1" == "-c" ]; then CSRtype="client"; fi
	shift
    done

    # Mandatory FQHN.
    local FQHN=$1; shift
    if [ -z "$FQHN" ]; then log "$MSG_WSM_SIGN_NOFQHN"; exit $EXIT_ERR; fi
    if [ ! -z "$(echo "$FQHN" | $SED "s/$MASKWEB//")" ]; then log "$MSG_WSM_SIGN_WRONGFQHN"; return $EXIT_ERR; fi

    # Mandatory certificate signing request.
    local CSR=$1; shift
    if [ -z "$CSR" ]; then log "$MSG_WSM_SIGN_NOCSR -"; exit $EXIT_ERR; fi
    if [ ! -r "$CSR" ]; then log "$MSG_WSM_SIGN_NOCSR $CSR"; exit $EXIT_ERR; fi
    # If corresponding certificate exists, we're ready :-).
    local CERT="$(echo "$CSR" | $SED 's/^\(.*\.\)\([^.]*\)$/\1/')pem"
    if [ ! -z "$CERT" -a -e "$CERT" -a -s "$CERT" ]; then return; fi
    # Verifying CSR (formally OK and has subject).
    $OPENSSL req -noout -subject -in "$CSR" >/dev/null 2>&1; result=$?
    if [ "$result" -ne 0 ]; then log "$MSG_WSM_SIGN_NOCSR $CSR"; exit $EXIT_ERR; fi

    # Optional CA certificate to use to sign. Defaults to FQHN's own CA certificate (if any).
    local CA=${1:-$FQHN.CA}; shift
    if [ ! -z "`echo "$CA" | $SED "s/$MASKCERT//"`" ]; then log "$MSG_WSM_SIGN_WRONGCERT"; return $EXIT_ERR; fi
    # Verifying CA, locating its OpenSSL CA configuration (CAconf)
    # and certificate revocation list (CArev, if any).
    local CAcert=""
    local CAkey=""
    local CAconf=""
    local CArev=""
    # Is a local (website) CA (subfoldered configuration)?
    if [ -r "$APACHEAUTHDIR/${CA%'.CA'}/$CA.key" -a -r "$APACHEAUTHDIR/${CA%'.CA'}/$CA.pem" ]; then
	CAcert="$APACHEAUTHDIR/${CA%'.CA'}/$CA.pem"
	CAkey="$APACHEAUTHDIR/${CA%'.CA'}/$CA.key"
	log "$MSG_WSM_SIGN_CALOCAL $APACHEAUTHDIR/${CA%'.CA'}/$CA"
	# Check configuration according to the wsm2 policy.
	if [ -r "$APACHEAUTHDIR/${CA%'.CA'}/$CA.cnf" ]; then CAconf="$APACHEAUTHDIR/${CA%'.CA'}/$CA.cnf"; fi
	if [ -r "$APACHEAUTHDIR/${CA%'.CA'}/$CA.crl" ]; then CArev="$APACHEAUTHDIR/${CA%'.CA'}/$CA.crl"; fi
    # Again, is a local (website) CA (traditional configuration)?
    elif [ -r "$APACHEAUTHDIR/$CA.key" -a -r "$APACHEAUTHDIR/$CA.pem" ]; then
	CAcert="$APACHEAUTHDIR/$CA.pem"
	CAkey="$APACHEAUTHDIR/$CA.key"
	log "$MSG_WSM_SIGN_CALOCAL $APACHEAUTHDIR/$CA"
	# Check configuration according to the wsm2 policy.
	if [ -r "$APACHEAUTHDIR/$CA.cnf" ]; then CAconf="$APACHEAUTHDIR/$CA.cnf"; fi
	if [ -r "$APACHEAUTHDIR/$CA.crl" ]; then CArev="$APACHEAUTHDIR/$CA.crl"; fi
    # Is a CA globally (system-wide) installed?
    elif [ -r "$SSLKEYSDIR/$CA.key" -a -r "$SSLCERTDIR/$CA.pem" ]; then
	CAcert="$SSLCERTDIR/$CA.pem"
	CAkey="$SSLKEYSDIR/$CA.key"
	log "$MSG_WSM_SIGN_CAGLOBAL $CA"
	# Where is its configuration? First hit wins.
	for folder in "$SSLCONFDIR/$CA" "$SSLCONFDIR" "$APACHEAUTHDIR/$CA" "$APACHEAUTHDIR"
	do
	    if [ -z "$CAconf" -a  -r "$folder/$CA.cnf" ]; then CAconf="$folder/$CA.cnf"; fi
	    if [ -z "$CAconf" -a  -r "$folder/$CA.crl" ]; then CArev="$folder/$CA.crl"; fi
	done
	# System-wide OpenSSL configuration is the last refuge :-).
	if [ -z "$CAconf" -a  -r "$SSLCONF" ]; then CAconf="$SSLCONF"; fi
    fi
    # Giving up if no CA or isn't able to sign.
    if [ -z "$CAcert" -o -z "$CAkey" -o -z "$CAconf" -o \
         -z "$($OPENSSL x509 -text -noout -in "$CAcert" 2>/dev/null | $GREP -i "CA:TRUE")" ]; then
	log "$MSG_WSM_SIGN_NOCA $CA"
	return $EXIT_ERR
    fi
    # We have a usable CA here.

    # Signing the request - trying CA method with verified CA,
    # using its configuration and taking care of the requested extensions.
    if [ ! -e "$CERT" -o ! -s "$CERT" ]; then
	if [ "$CSRtype" == "server" ]; then
	    # Server certificate signing with ca method.
	    $OPENSSL ca -notext -batch -md sha256 \
	                -config "$CAconf" \
	    	        -in "$CSR" \
		        -out "$CERT" \
	                2>/dev/null
	    result=$?
	else
	    # Client certificate signing with ca method.
	    $OPENSSL ca -notext -batch -md sha256 \
		        -policy policy_anything -extensions v3_client \
		        -config "$CAconf" \
	    	        -in "$CSR" \
		        -out "$CERT" \
	                2>/dev/null
	    result=$?
	fi
	# Report the success or failure.
	if [ ! -e "$CERT" -o ! -s "$CERT" ]; then
	    log "$MSG_WSM_SIGN_CERTFAILED $CERT (ca:$result)"
	else
	    log "$MSG_WSM_SIGN_CERTOK $CERT (ca:$result)"
	fi
    fi
    # Signing the request - trying x509 method with verified CA's key
    # and with extensions configured in wsm. Extensions requested
    # in CSR will be ignored here.
    if [ ! -e "$CERT" -o ! -s "$CERT" ]; then
	if [ "$CSRtype" == "server" ]; then
	    # Server certificate signing with x509 method.
    	    $OPENSSL x509 -req -days $SSLCERTDAYS -set_serial $($DATE '+%s%N') \
	                  -extfile "$WSMTEMPLATEDIR/$WSMSGNSRVCONF" \
		          -in "$CSR" \
		          -CA "$CAcert" -CAkey "$CAkey" -sha256 \
		          -out "$CERT" \
		          2>/dev/null
	    result=$?
	else
	    # Client certificate signing with x509 method.
    	    $OPENSSL x509 -req -days $SSLCERTDAYS -set_serial $($DATE '+%s%N') \
	                  -extfile "$WSMTEMPLATEDIR/$WSMSGNCLICONF" \
		          -in "$CSR" \
		          -CA "$CAcert" -CAkey "$CAkey" -sha256 \
		          -out "$CERT" \
		          2>/dev/null
	result=$?
	fi
	# Report the success or failure.
	if [ ! -e "$CERT" -o ! -s "$CERT" ]; then
	    log "$MSG_WSM_SIGN_CERTFAILED $CERT (x509:$result)"
	else
	    log "$MSG_WSM_SIGN_CERTOK $CERT (x509:$result)"
	fi
    fi

    # Returns with a structure of CA parameters used.
    echo -e "$CAcert\n$CAkey\n$CAconf\n$CArev"
    return $result
}

# wsm_configure
# Graceful setup or reconfiguration of wsm2 environment.
function wsm_configure {

# Checking components and circumstances.
    if [ ! $UID -eq 0 ]; then echo -e "$MSG_WSM_ALL_ROOTNEED" >&2; return $EXIT_ERR; fi

# Logs handling: wsm2 log creation (rotated via Apache cronjob).
# Must be the 1st step to enable logging configuration process itself.
    if [ ! -f "$WSMLOGFILE" ]; then
        touch $WSMLOGFILE; chown root:root $WSMLOGFILE; chmod 640 $WSMLOGFILE
        log "$MSG_WSM_CONF_LOGFILE_CREATED" "$WSMLOGFILE"
    fi

# Creating timestamp to name backup files and logfile.
    timestamp="$(date '+%Y%m%d%H%M%S')"

# Configuration itself.
    log "$MSG_WSM_CONF_DEBIAN $DEBIAN_MAIOR.x"
    log $($APACHEDAEMON stop 2>/dev/null)

    log $MSG_WSM_CONF_GLOBAL
    # Hardening access rights for web storage (others --X).
    chown $APACHEADMIN:$APACHEADMINGROUP $APACHEDOCROOT
    chmod 2751 $APACHEDOCROOT; $SETFACL -d -m o::X $APACHEDOCROOT
    # Read access to disk group for backup purposes.
    $SETFACL -m g:$APACHEBACKUPGROUP:rx $APACHEDOCROOT
    # Removing default frontpage if any.
    rm     $APACHEDOCROOT/index.html 2>/dev/null # Before Jessie
    rm -Rf $APACHEDOCROOT/html       2>/dev/null # Jessie +
    # Creating folder for per-virtualhost certificates and basic authentication credentials.
    if [ ! -d $APACHEAUTHDIR ]; then log $(mkdir --verbose -m 755 $APACHEAUTHDIR 2>&1); fi
    # Creating multiuser WebDAV lock directory.
    # Note: Wheezy+ needs to recreate on every boot by a cron job.
    if [ ! -d $APACHELOCKDIR ]; then
        log $(mkdir --verbose -m 2770 $APACHELOCKDIR 2>&1)
        chown $APACHEUSER:$APACHEGROUP $APACHELOCKDIR
        $SETFACL -d -m g::rwX $APACHELOCKDIR
    fi
    # Modifying access control on log directory (read for web administrator).
    if [ -d $APACHELOGDIR ]; then
        $SETFACL    -m u:$APACHEADMIN:rX $APACHELOGDIR
        $SETFACL -d -m u:$APACHEADMIN:r  $APACHELOGDIR
    fi
    # wsm2 global configuration becomes a symlinked template, local becomes a copy.
    # Jessie and above needs a .conf extension.
    if [ ! -e "$APACHECONFIGDIR/$WSMCONFIGFILE$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )" ]; then
	# Maybe a Debian version dependent template.
	if [ -f "$WSMTEMPLATEDIR/$WSMCONFIGFILE.$DEBIAN_MAIOR" ]; then
    	    log $(ln -v -s "$WSMTEMPLATEDIR/$WSMCONFIGFILE.$DEBIAN_MAIOR" \
	                   "$APACHECONFIGDIR/$WSMCONFIGFILE$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )")
	else
    	    log $(ln -v -s "$WSMTEMPLATEDIR/$WSMCONFIGFILE" \
	                   "$APACHECONFIGDIR/$WSMCONFIGFILE$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )")
	fi
    fi
    # Copying wsm2 local configuration template.
    if [ ! -f "$APACHECONFIGDIR/$WSMCONFIGLOCAL$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )" ]; then
	# Maybe a Debian version dependent template.
	if [ -f "$WSMTEMPLATEDIR/$WSMCONFIGLOCAL.$DEBIAN_MAIOR" ]; then
    	    log $(cp -v -p "$WSMTEMPLATEDIR/$WSMCONFIGLOCAL.$DEBIAN_MAIOR" \
	                   "$APACHECONFIGDIR/$WSMCONFIGLOCAL$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )")
	else
    	    log $(cp -v -p "$WSMTEMPLATEDIR/$WSMCONFIGLOCAL" \
	                   "$APACHECONFIGDIR/$WSMCONFIGLOCAL$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )")
	fi
    fi
    # Enabling new configurations if necessary (Jessie +).
    if [ -x "$APACHEENCONF" ]; then log $("$APACHEENCONF" "$WSMCONFIGFILE" "$WSMCONFIGLOCAL"); fi
    # Copying urlcheck templates.
    if [ ! -f "$URLCHECK_EXC" ]; then
        log $(cp -v -p "$WSMTEMPLATEDIR/$($BASENAME $URLCHECK_EXC)" "$URLCHECK_EXC") #"
    fi
    if [ ! -f "$URLCHECK_HOSTS" ]; then 
        log $(cp -v -p "$WSMTEMPLATEDIR/$($BASENAME $URLCHECK_HOSTS)" "$URLCHECK_HOSTS") #"
    fi

    # Setting modules (Debian version dependent).
    log $MSG_WSM_CONF_MODULES
    if [ "$DEBIAN_MAIOR" -ge 8 ]; then
	# Jessie +
	log $($APACHEDISMOD cgi cgid) # CGI isn't enabled by default, but safety first :-)
	log $($APACHEDISCONF serve-cgi-bin) # Another way to disable CGI
	log $($APACHEENMOD authz_groupfile dav_fs expires headers proxy_http rewrite ssl)
    else
	# Otherwise
	log $($APACHEDISMOD cgi)
	log $($APACHEENMOD dav_fs expires geoip headers mod-security proxy_http rewrite ssl)
    fi

    # Setting ModSecurity.
    log $MSG_WSM_CONF_MODSEC
    # Creating multiuser workspace folders.
    if [ ! -d $WSMMODSECDIR ]; then
        log $(mkdir --verbose -m 2770 $WSMMODSECDIR 2>&1)
        chown $APACHEUSER:$APACHEGROUP $WSMMODSECDIR
        $SETFACL -d -m g::rwX $WSMMODSECDIR
        for folder in $WSMMODSECDIRS
        do
            if [ ! -d "$WSMMODSECDIR/$folder" ]; then
                log $(mkdir --verbose -m 2770 "$WSMMODSECDIR/$folder" 2>&1)
                chown $APACHEUSER:$APACHEGROUP "$WSMMODSECDIR/$folder"
            fi
        done
    fi
    # Creating configuration folder.
    if [ ! -d $WSMMODSECCONFDIR ]; then
        log $(mkdir --verbose $WSMMODSECCONFDIR 2>&1)
    fi
    # Creating folder for core ruleset updates.
    if [ ! -d $WSMMODSECCONFDIR/$WSMMODSECCRSDIR ]; then
        log $(mkdir --verbose -m 750 $WSMMODSECCONFDIR/$WSMMODSECCRSDIR 2>&1)
    fi
    # Symlinking the builtin core ruleset, copying the WSM2 errata configurtion also.
    for config in $WSMMODSECCONFS
    do
	if [ ! -e $WSMMODSECCONFDIR/$config ]; then
	    # Maybe a Debian version dependent template.
	    if [ -f "$WSMTEMPLATEDIR/$config.$DEBIAN_MAIOR" ]; then
		cp -p -d "$WSMTEMPLATEDIR/$config.$DEBIAN_MAIOR" "$WSMMODSECCONFDIR/$config"
		log "$WSMTEMPLATEDIR/$config.$DEBIAN_MAIOR -> $WSMMODSECCONFDIR/$config"
	    else
		cp -p -d "$WSMTEMPLATEDIR/$config" "$WSMMODSECCONFDIR/$config"
		log "$WSMTEMPLATEDIR/$config -> $WSMMODSECCONFDIR/$config"
	    fi
	fi
    done
    # The new way of ModSecurity CRS rules activation (Jessie+):
    # symlinking the base rules into the activated_rules folder.
    if [ "$DEBIAN_MAIOR" -ge 8 -a -d "$WSMMODSECCONFDIR/rules/base_rules" -a -d "$WSMMODSECCONFDIR/rules/activated_rules" ]; then
	for config in $WSMMODSECCONFDIR/rules/base_rules/*.data $WSMMODSECCONFDIR/rules/base_rules/*.conf
	do
	    if [ ! -L "$WSMMODSECCONFDIR/rules/activated_rules/$($BASENAME "$config")" ]; then
		log $(ln -s -v ../base_rules/$($BASENAME "$config") "$WSMMODSECCONFDIR/rules/activated_rules/$($BASENAME "$config")")
	    fi
	done
    fi
    # Copying and customizing local ModSecurity (main) configuration template.
    # Jessie and above needs a .conf extension.
    if [ ! -f "$APACHECONFIGDIR/$WSMMODSECLOCAL$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )" ]; then
        export APACHELOGDIR WSMMODSECDIR WSMMODSECCONFDIR
	# Maybe a Debian version dependent template.
	if [ -f "$WSMTEMPLATEDIR/$WSMMODSECLOCAL.$DEBIAN_MAIOR" ]; then
    	    cat "$WSMTEMPLATEDIR/$WSMMODSECLOCAL.$DEBIAN_MAIOR" | $ENVSUBST >\
	        "$APACHECONFIGDIR/$WSMMODSECLOCAL$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
	    log "$WSMTEMPLATEDIR/$WSMMODSECLOCAL.$DEBIAN_MAIOR ->" \
	        "$APACHECONFIGDIR/$WSMMODSECLOCAL$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
	else
    	    cat "$WSMTEMPLATEDIR/$WSMMODSECLOCAL" | $ENVSUBST >\
	        "$APACHECONFIGDIR/$WSMMODSECLOCAL$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
	    log "$WSMTEMPLATEDIR/$WSMMODSECLOCAL ->" \
	        "$APACHECONFIGDIR/$WSMMODSECLOCAL$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )"
	fi
	# Enabling new configuration if necessary (Jessie +).
	if [ -x "$APACHEENCONF" ]; then log $("$APACHEENCONF" "$WSMMODSECLOCAL"); fi
    fi

    # Setting AwStats and GeoIP databases.
    log $MSG_WSM_CONF_AWSTATS
    # Symlinking necessary Perl scripts.
    for plfile in $AWSTATSPROGS
    do
	# Try maintainer's examples folder.
        if [ ! -L $AWSTATSBINDIR/$plfile -a -f $AWSTATSEXAMPLEDIR/$plfile ]; then
            log $(ln -v -s $AWSTATSEXAMPLEDIR/$plfile $AWSTATSBINDIR/$plfile)
        fi
	# Try maintainer's tools folder.
        if [ ! -L $AWSTATSBINDIR/$plfile -a -f $AWSTATSTOOLSDIR/$plfile ]; then
            log $(ln -v -s $AWSTATSTOOLSDIR/$plfile $AWSTATSBINDIR/$plfile)
        fi
    done
    # Copying AwStats exceptions and hosts templates.
    if [ ! -f "$AWSTATS_EXC" ]; then
        log $(cp -v -p $WSMTEMPLATEDIR/$($BASENAME "$AWSTATS_EXC") "$AWSTATS_EXC")
    fi
    if [ ! -f "$AWSTATS_HOSTS" ]; then
        log $(cp -v -p $WSMTEMPLATEDIR/$($BASENAME "$AWSTATS_HOSTS") "$AWSTATS_HOSTS")
    fi
    # Creating AwStats results HTML folder.
    if [ ! -d $AWSTATSWEBROOT ]; then
        log $(mkdir --verbose -m 2750 $AWSTATSWEBROOT 2>&1)
        chown $APACHEADMIN:$APACHEADMINGROUP $AWSTATSWEBROOT
    fi
    # Moving GeoIPFree database to R/W partition.
    if [ ! -f $GEOIPDATABASE ]; then
        log $(mv -v $GEOIPSOURCE $GEOIPDATABASE)
        log $(ln -v -s $GEOIPDATABASE $GEOIPSOURCE)
    fi
    # Moving GeoIP Lite Country database to R/W partition.
    if [ ! -f $GEOLITEDATABASE ]; then
        log $(mv -v $GEOLITESOURCE $GEOLITEDATABASE)
        log $(ln -v -s $GEOLITEDATABASE $GEOLITESOURCE)
    fi

    # Setting PHP (if any).
    if [ -d "$PHPCONFDIR" ]; then
	log $MSG_WSM_CONF_PHP5
	if [ ! -f "$PHPCONFDIR/99-$PHPCONFFILE" ]; then
	    # Try to detect current time zone.
	    if [ -x "$(which timedatectl)" ]; then
		timezone=$(env LANG=C $(which timedatectl) status | \
                           $GREP -i 'time zone' | \
                           $SED 's/^.* \([[:alpha:]]\+\/[[:alpha:]]\+\) .*$/\1/')
	    else
		timezone=$(wsm2_geolocate "$DEFAULT_HOSTNAME" | $TAIL -n1 | $CUT -d ',' -f7);
	    fi
	    export timezone
	    # Maybe a Debian version dependent template.
	    if [ -f "$WSMTEMPLATEDIR/$PHPCONFFILE.$DEBIAN_MAIOR" ]; then
		# Jessie and above recommends a numeric prefix.
		cat "$WSMTEMPLATEDIR/$PHPCONFFILE.$DEBIAN_MAIOR" | $ENVSUBST >\
		    "$PHPCONFDIR/$([ "$DEBIAN_MAIOR" -ge 8 ] && echo '99-' )$PHPCONFFILE"
		log "$WSMTEMPLATEDIR/$PHPCONFFILE.$DEBIAN_MAIOR -> $PHPCONFDIR/$([ "$DEBIAN_MAIOR" -ge 8 ] && echo '99-' )$PHPCONFFILE"
	    else
		cat "$WSMTEMPLATEDIR/$PHPCONFFILE" | $ENVSUBST >\
		    "$PHPCONFDIR/$([ "$DEBIAN_MAIOR" -ge 8 ] && echo '99-' )$PHPCONFFILE"
		log "$WSMTEMPLATEDIR/$PHPCONFFILE -> $PHPCONFDIR/$([ "$DEBIAN_MAIOR" -ge 8 ] && echo '99-' )$PHPCONFFILE"
	    fi
	fi
    fi

    # Common server certificate: symlinking the packaged ("snakeoil") certificate.
    if [ ! -e "$SSLCERTDIR/$DEFAULT_HOSTNAME.pem" ]; then
        log "$MSG_WSM_CONF_DEFAULT_CERT"
        log $(ln -v -s "$SSLCERTDIR/ssl-cert-snakeoil.pem" "$SSLCERTDIR/$DEFAULT_HOSTNAME.pem")
        rm -f "$SSLKEYSDIR/$DEFAULT_HOSTNAME.key" 2>/dev/null
        log $(ln -v -s "$SSLKEYSDIR/ssl-cert-snakeoil.key" "$SSLKEYSDIR/$DEFAULT_HOSTNAME.key")
    else
        log "$MSG_WSM_CONF_DEFAULT_CERT_EXISTS"
    fi

    # Creating default virtualhost.
    if [ -L "$APACHEVHOSTSDIR/$DEFAULT_VHOST$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )" ]; then
        # Normally default configuration is a regular file;
        # when symlink found, it is created by wsm2 and nothing to do.
        log $MSG_WSM_CONF_DEFAULT_VHOST_EXISTS
    else
        log $MSG_WSM_CONF_DEFAULT_VHOST
        # Creating a new virtualhost.
        wsm_createweb "$DEFAULT_HOSTNAME" "$DEFAULT_EMAIL" "$DEFAULT_CERT"
        # Activating new virtualhost as default.
        log $($APACHEDISSITE $DEFAULT_VHOST)
        log $($APACHEDISSITE $DEFAULT_HOSTNAME)
        # Backing up exisitng default and symlinking just created.
        mv "$APACHEVHOSTSDIR/$DEFAULT_VHOST$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )" "$APACHEVHOSTSDIR/$DEFAULT_VHOST.$timestamp"
        log $(ln -s "$APACHEVHOSTSDIR/$DEFAULT_HOSTNAME$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )" \
                    "$APACHEVHOSTSDIR/$DEFAULT_VHOST$([ "$DEBIAN_MAIOR" -ge 8 ] && echo ".conf" )") #"
        log $($APACHEENSITE $DEFAULT_VHOST)
    fi

# Finally go on with Apache!
    log $($APACHEDAEMON start)
    return
}

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

# Helper function: geolocate paramater IP or FQHN via 3rd party web service.
# Results a comma-separated list of attributes below:
# countryname, countrycode, localitycode, localityname, latitude, longitude, timezone
# Additionally returns a 2nd line completed with guessed or defaults value.
function wsm_geolocate {
    local countryname countrycode localitycode localityname latitude longitude timezone
    local result

    local FQHN=$1; shift
    # Parameter checked formally.
    if [ ! -z "$FQHN" -a  -z "$(echo "$FQHN" | $SED "s/$MASKWEB//")" ]; then
	# Geolocating itself.
	if [ ! -z "$(echo $GEOLOCATEURL | $GREP 'ip-api.com')" ]; then
	    # Using ip-api.com webservice, parsing results.
	    result=$($WGET -nv -O - "$GEOLOCATEURL$FQHN" 2>/dev/null | $GREP 'success')
	    countryname=$(echo $result  | $CUT -d, -f2)
	    countrycode=$(echo $result  | $CUT -d, -f3)
	    localitycode=$(echo $result    | $CUT -d, -f4)
	    localityname=$(echo $result | $CUT -d, -f6)
	    latitude=$(echo $result     | $CUT -d, -f8)
	    longitude=$(echo $result    | $CUT -d, -f9)
	    timezone=$(echo $result     | $CUT -d, -f10)
	fi
    fi
    # 1st result line contains the real parameters resolved.
    echo $countryname,$countrycode,$localitycode,$localityname,$latitude,$longitude,$timezone

    # 2nd line of the result may be used as a reasonable guess or default value set.
    if [ -z "$countryname$countrycode$localitycode$localityname$timezone" ]; then
	# Absolutely no result was retrieved.
	countryname="United States"
	countrycode="US"
	localitycode="NY"
	localityname="New York"
	timezone="America/New_York"
    fi
    # Country name and code hacking.
    if [ -z "$countryname" -a ! -z "$countrycode" ]; then countryname=$countrycode; fi
    if [ -z "$countrycode" -a ! -z "$countryname" ]; then countrycode=$countryname; fi
    # Locality from time zone.
    if [ -z "$localitycode$localityname" -a ! -z "$timezone" ]; then localityname=$(echo $timezone | $CUT -d/ -f2); fi
    # Locality name and locality code hacking.
    if [ -z "$localityname" -a ! -z "$localitycode" ]; then localityname=$localitycode; fi
    if [ -z "$localitycode" -a ! -z "$localityname" ]; then localitycode=$localityname; fi
    # Country from locality hacking.
    if [ -z "$countryname" -a ! -z "$localityname" ]; then
	countryname=$localityname
	countrycode=$localitycode
    fi
    # Maybe hacked results line (as a suggestion) will be returned also.
    echo $countryname,$countrycode,$localitycode,$localityname,$latitude,$longitude,$timezone | $SED "s/\"//g"

    return
}

#
# Main program - handling options
#

option=`echo $1 | $SED -n "s/^-\+//p"`; if [ ! -z "$option" ]; then shift; fi
case "$option" in
    "cw"|"createweb")
        wsm_createweb "$@"; exit $?
    ;;
    "cwca"|"createwebwithca")
	# Only the certificate (3rd) argument will be modified below:
	# if was empty, ordering a local CA, dedicated to this virtualhost.
	args=( "$@" )
	args[0]=${1:-''}; args[1]=${2:-''}; args[2]=${3:-${args[0]}.CA}
	set "${args[@]}"
        wsm_createweb "$@"; exit $?
    ;;
    "rw"|"removeweb")
        wsm_removeweb "$@"; exit $?
    ;;
    "sw"|"saveweb")
        wsm_saveweb "$@"; exit $?
    ;;
    "au"|"adduser")
        wsm_adduser "$@"; exit $?
    ;;
    "du"|"deluser")
        wsm_deluser "$@"; exit $?
    ;;
    "ag"|"addgroup")
        wsm_addgroup "$@"; exit $?
    ;;
    "dg"|"delgroup")
        wsm_delgroup "$@"; exit $?
    ;;
    "aug"|"addusertogroup")
        wsm_addusertogroup "$@"; exit $?
    ;;
    "dug"|"deluserfromgroup")
        wsm_deluserfromgroup "$@"; exit $?
    ;;
    "lug"|"listusersgroup")
        wsm_listusersgroup "$@"; exit $?
    ;;
    "ca"|"certificateauthority")
	wsm_ca "$@"; exit $?
    ;;
    "cert"|"certificate")
        wsm_certificate "$@"; exit $?
    ;;
    "client"|"clientcertificate")
        wsm_client "$@"; exit $?
    ;;
    "revoke"|"revokecertificate")
        wsm_revoke "$@"; exit $?
    ;;
    "sign"|"signcertificate")
	wsm_sign "$@"; exit $?
    ;;
    "geolocate")
	wsm_geolocate "$@"; exit $?
    ;;
    "configure"|"install")
        wsm_configure "$@"; exit $?
    ;;
    *)
        echo -e "$USAGE"; exit $EXIT_ERR
    ;;
esac

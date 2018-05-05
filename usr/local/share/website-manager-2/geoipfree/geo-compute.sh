#!/bin/bash
# Simple script to convert an IP CSV file to the GeoIPFree format.
# Based on geoip.sh by Chris Gage, Part of website-manager-2 package.
#
# Usage: $0 path_to_csv_file [path_to_geoipfree_file]
# Prints to standard output if path_to_geoipfree_file isn't given.
# Alternative call: echo -e "path_to_csv_file\npath_to_geoipfree_file" | $0

# Including headers (if any).
HEADERS="/etc/default/wsm2-geoipfree"
if [ -f "$HEADERS" ]; then . $HEADERS; fi

# Getting parameters
INFILE=$1; shift
if [ -z "$INFILE" ]; then
    read -s -t 1 INFILE
fi
if [ ! -f "$INFILE" ]; then exit 101; fi

OUTFILE=$1; shift
if [ -z "$OUTFILE" ]; then
    read -s -t 1 OUTFILE
fi
if [ -f "$OUTFILE" ]; then exit 102; fi

# Parsing $INFILE to $OUTFILE or standard output.
cat $INFILE | while read NEXTLINE
do
    TEST=`echo "$NEXTLINE" |  egrep '^[[:digit:]]*,[[:digit:]]*,[[:upper:]]*$'`
    if [ ! -z  "$TEST" ]; then
        NUM1=`echo $NEXTLINE|cut -d, -f1|sed 's/\"//g'`
        NUM2=`echo $NEXTLINE|cut -d, -f2|sed 's/\"//g'`
        CNTRY=`echo $NEXTLINE|cut -d, -f3|sed 's/\"//g'`

        # Converting IP ranges to IP.IP.IP.IP format.
        TEMP=`expr 256 "*" 256 "*" 256`
        A1=`expr $NUM1 "/" $TEMP`
        NUM1=`expr $NUM1 "-" $TEMP "*" $A1`
        A2=`expr $NUM2 "/" $TEMP`
        NUM2=`expr $NUM2 "-" $TEMP "*" $A2`

        TEMP=`expr 256 "*" 256`
        B1=`expr $NUM1 "/" $TEMP`
        NUM1=`expr $NUM1 "-" $TEMP "*" $B1`
        B2=`expr $NUM2 "/" $TEMP`
        NUM2=`expr $NUM2 "-" $TEMP "*" $B2`

        TEMP=256
        C1=`expr $NUM1 "/" $TEMP`
        NUM1=`expr $NUM1 "-" $TEMP "*" $C1`
        C2=`expr $NUM2 "/" $TEMP`
        NUM2=`expr $NUM2 "-" $TEMP "*" $C2`

        IP1=${A1}.${B1}.${C1}.${NUM1}
        IP2=${A2}.${B2}.${C2}.${NUM2}

        # Writing converted data
        if [ ! -z "$OUTFILE" ]; then
            echo "${CNTRY}: $IP1 $IP2" >> $OUTFILE
        else
            echo "${CNTRY}: $IP1 $IP2"
        fi
    fi
done

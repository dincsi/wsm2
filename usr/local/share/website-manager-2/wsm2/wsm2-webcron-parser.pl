#!/usr/bin/perl -w
#
# Simple filter to determine jobs to run in this minute from a crontab file.
# Usage: pipe in a crontab file, results jobs to run (one unique job by line).
# Part of website-manager-2 package.
#
# Originally from:
# http://stackoverflow.com/questions/4053463/find-cron-jobs-that-run-between-given-times
# Sorry about my terrible english and I'm a Perl noob...

use strict;

my @jobList;
# Getting local time "now" in cron format: min hrs dom mnt dow.
# Storing possible range of values also (min: 0-59, hrs: 0-23 etc.).
my @timeData = localtime(time);
my @now = ( [$timeData[1],   0, 59],
            [$timeData[2],   0, 23],
            [$timeData[3],   1, 31],
            [1+$timeData[4], 1, 12],
            [$timeData[6],   0, 6] );

# Getting crontab from STDIN.
my @crontab = <STDIN>;
# Enumerating lines, skiping comments and empty lines.
foreach my $cronjob (@crontab){
    chomp $cronjob;
    next if $cronjob =~ /^ *\#/ ||$cronjob =~ /^ *$/  ;
    # Split into array: min hrs dom mnt dow
    my @cronLine = split(/\s+/, $cronjob);
    #print "@cronLine\n";
    # Comparing corresponding entries, on mismatch breaking comparison
    # and continuing with next cron line.
CRONLINE: {
	for (my $count = 0; $count < @now; $count++) {
	    my @range = expandRange($cronLine[$count],$now[$count][1],$now[$count][2]);
	    #print "expanded range: @range, timedata: $now[$count][0]\n";
	    # Current time data: @now[$count][0] matches the range?
	    if (grep {$_ eq $now[$count][0]} @range) {
		#print "expanded range: @range, timedata: $now[$count][0]\n";
	    }
	    else {
		# On mismatch we're done with this cronline.
		last CRONLINE;
	    }
	}
	# Cycle terminated succesfully, cron job need to run.
	# We remove processed datetime items from cron line before printing.
	for (my $count = 0; $count < @now; $count++) {
	    shift(@cronLine);
	}
	print "@cronLine\n";
    }
}

# Subroutine to expand an integer range from cron-style date/time value.
# Interprets n, *, */q, n-m, n-m/q formats.
# Parameters: cron-style_value, possible_bottom, possible_top
# (e.g. for mins: 0-59/2,0,59; for months: 1-6,1,12).
# Results a list of numeric-sorted discrete values.
sub expandRange {

    # Getting parameters.
    my ($in,$begin,$end) = @_;
    my @range;
    # Parsing comma-delimited values, each value evaluated as a separate range.
    my @vals = split(/,/,$in);
    foreach my $val (@vals) {
	# Value may contain a divider (/2 for example), we need extract them.
	my $mult = 1;
	if($val =~ /\/(.+)$/) {
	    $mult = $1;
	    $val =~ s/\/(.+)//;
	}
	# $mult contains divider, $val contains all given before the divider.
	#
	# If $val contains '*' will be substitued with the whole possible range
	# divided by divider.
	if($in =~ /\*/) {
	    @range = grep { $_ % $mult == 0 && $_ >= $begin &&  $_ <= $end  } $begin..$end;
	}
	# If $val contains '-' (for example 5-10) will be substitued
	# by the range between limits given and result divided by divider.
	elsif($val =~ /[\-:]/) {
	    my ($first, $last) = split(/[\-:]/,$val);
	    push(@range, grep {  $_ % $mult == 0 && $_ >= $begin &&  $_ <= $end } $first..$last);
	}
	# If $val contains a discrete value within possible range,
	# simply added to range. Divider isn't applied(?).
	elsif($val >= $begin &&  $val <= $end) {
	    push(@range, $val);
	}
    }
    #print "range: @range\n";

    # Unique sorted range resulted.
    my %unique;
    @unique{@range} = 1;
    return sort { $a <=> $b } keys %unique;
}

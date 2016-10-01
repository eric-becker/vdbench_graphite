#!/bin/bash

# vdbench_graphite.sh is a bash script to feed parsed vdbench output to graphite
# 
# Requires netcat (nc), tee, awk, graphite, and vdbench 
# http://www.oracle.com/technetwork/server-storage/vdbench-downloads-1901681.html
#
# To execute, simply run vdbench and pipe to this script.  By default it will send stats to graphite localhost:2003 
# vdbench.default.[HOSTNAME].[METRIC]  There are no required options, but additional parameters can be passed to   
# change the destination host and/or port as well as a custom tag instead of using the hostname.  To implement multiple
# custom tags simply separate the tags with periods.
#
# It is also possible to feed the stats from an existing vdbench workload provided stdout was written to a file. 
# Simply cat the vdbench output file and redirect to vdbench_graphite.sh the same as above.  Note: original timestamps
# are used for the metrics so it will be necessary to look at the graph historically. 
#
# ./vdbench -f foo.vdb -o outdir.foo | vdbench_graphite.sh -h [graphite_host] -p [graphite_port] -t [graphite_tag] -o console.foo


while [[ $# > 1 ]]
do
key="$1"

case $key in
    -h|--host)
    graphite_host="$2"
    shift 
    ;;
    -p|--port)
    graphite_port="$2"
    shift
    ;;
    -t|--tag)
    tag="$2"
    shift
    ;;
    -o|--outfile)
    outfile="$2"
    ;;
    *)
        
    ;;
esac
shift
done

echo

# Assume graphite is running on localhost if not defined 
if [ -z "$graphite_host" ] ; then
    echo "Graphite host \"-h\" not defined, assuming localhost."
    graphite_host="localhost"
fi

# Addume graphite is running on port 2003 if not defined
if [ -z "$graphite_port" ] ; then
    echo "Graphite port \"-p\" not defined, assuming 2003." 
    graphite_port="2003"
fi

# Check to make sure we can talk to graphite before continuing 
#nc -z $graphite_host $graphite_port 

#if [ "$?" != "0" ]; then
#    echo "Can't communicate with graphite at $graphite_host on TCP port $graphite_port."
#    exit
#fi

# Assign a prefix based on tag
if [ -z "$tag" ]; then
    prefix=vdbench.default.`hostname -s`
else 
    prefix=vdbench.$tag.`hostname -s`
fi

# If not outfile specified, kick overything to /dev/null
if [ -z "$outfile" ]; then
    outfile="/dev/null"
fi

echo "Sending metrics to graphite $graphite_host $graphite_port at $prefix."

# Write a copy of everything coming in to another file
tee $outfile |

# Begin really awkward text parsing
awk -v prefix=$prefix '
BEGIN {
}

# Search for keyword "interval " to define the first title header
/  interval  / {
    # Use gsub to remove some unwanted characters
    gsub(/sec/,"",$0)
    gsub(/\//,"",$0)
    gsub(/\,/,"",$0)

    # Feed all the titles into an array
    title1_columns=split($0,title1_array," ")

    # Vdbench uses a string for the month, this converts it to a number and assigns it a variable
    month=(match("JanFebMarAprMayJunJulAugSepOctNovDec",title1_array[1])+2)/3

    # Assign day and year to variables
    day=title1_array[2]
    year=title1_array[3]
}

# Search for keyword "rate" ot define the second title header
/^\s*rate/ {
    # Replace 1024**2 with sec so we can mash it from a header from the above section to get MB/sec
    gsub(/1024\*\*2/,"sec",$0)
	
    # Use gsub to remove an unwanted /
    gsub(/\//,"",$0)

    # Feed all the second titles into an array
    title2_columns=split($0,title2_array," ")

    # Only get some of them because of vdbench formatting
    title1_column=4
    title2_column=0
    title_column=1
    while (title1_column <= title1_columns) {
        title_array[title_column]=title1_array[title1_column] title2_array[title2_column]

        title1_column++
        title2_column++
        title_column++	
    }		
}

# Search for any lines that do not have letters, assumed to be vdbench metrics
!/[a-z]/ {
    # Simple check to make sure that we have the month (and presumable day and year) before continuing
    if ( title1_array[1] != "" ) {
        # Feed all the metrics into an array
        stats_columns=split($0,stats_array," ")
        sub(/\..*/,"",stats_array[1])

        split(stats_array[1],timestamp,":")
        hour=timestamp[1]
        min=timestamp[2]
        sec=timestamp[3]

        # Convert time to epoch time
        epochtime=mktime(year " " month " " day " " hour " " min " " sec)

        title_column=1
        stats_column=2

        # Do stuff and things
        while (stats_column <= stats_columns) {


	    # Spit out the formatted metrics in graphite friendly format
            print prefix"."title_array[title_column] " " stats_array[stats_column] " " epochtime
            title_column++
            stats_column++
        } 
    }
}

END {
}
' | (nc $graphite_host $graphite_port)

# Wait until previous commands finish before continuing
wait

echo
echo "Done"

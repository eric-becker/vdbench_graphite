# vdbench_graphite
A simple bash script to help graph vdbench in real-time or post process.  This script parses vdbench output and feeds it to graphite using original timestamps. Includes an example grafana dashboard that can be tweaked as needed.

![vdbench_graphite dashboard](https://cloud.githubusercontent.com/assets/2933063/18571124/8eab3210-7b75-11e6-83e4-de36763f1722.png "vdbench_graphite dashboard")

## Install
Place vdbench_graphite.sh somewhere on the server(s) running vdbench.  

## Requirements
1. netcat
2. awk 
3. tee
4. graphite (local or remote)
5. grafana 3.x (local or remote)

## Usage
Simply run vdbench and pipe to this script.  

```
./vdbench -f foo.vdb | vdbench_graphite.sh

Graphite host "-h" not defined, assuming localhost.
Graphite port "-p" not defined, assuming 2003.
Sending metrics to graphite localhost 2003 at vdbench.default.afa-poc-command.

```

The script will continue to receive input from vdbench in realtime, convert the vdbench timestamp to epoch, format the metrics to be graphite friendly, and send them to grpahite.  When the vdbench workload exits, so will the script.  This allows multiple vdbench iterations to run sequentially from within a bash script. 

By default stats will be sent to graphite running on localhost:2003 under vdbench.default.[HOSTNAME].[METRIC]  There are no required options, but additional parameters can be passed to change the destination host and/or port as well as a custom tag instead of using the hostname.  To implement multiple custom tags simply separate the tags with periods.  The -o option allows you to write the captured stdout to a file while still feeding graphite.

```
./vdbench -f foo.vdb -o outdir.foo | vdbench_graphite.sh -h server01 -p 2003 -t foo.baz -o console.foo
```

It is also possible to feed the stats from an existing vdbench workload provided stdout was written to a file. Simply cat the vdbench output file and redirect to vdbench_graphite.sh the same as above.  Note: original timestamps from vdbench stdout are converted to epoch and used for the timestamps for each metric fed to graphite.  As such, workload that was run a day prior would show up in graphite the previous day as well.  

```
cat console.foo | vdbench_graphite.sh -h server01 -p 2003 -t foo.baz 
```

You can additonally specify the hostname of the system where vdbench stats were collected if executing this script from another host.

```
cat console.foo | vdbench_graphite.sh -h server01 -p 2003 -t foo.baz -n host.example.com
```

Installing and configuring graphite and grafana are beyond the scope of this README.  As long as there is an appropriately configured storage schema for graphite, the graphs should look good.  If you notice gaps in the graphs verify that that the "interval=" parameter in your vdbench config matches the lowest retention period in storage-schemas.conf.  The easiest configuration (and highest granularity) is "interval=1" in the vdbench config and a stanza in storage-schemas.conf like:

```
[vdbench]
pattern = ^vdbench\.
retentions = 1s:7d, 5s:30d, 1m:90d
```

This will store metrics at 1 second granularity for 7 das, 5 second for 30 days, and 1 minute for 90 days.  Adjust as necessary for your needs. 

## Caveats
The single stat metrics at the top of the example dashboard can be hidden by clicking on the title.  They will always show the last update received so bear that in mind if updates stop, they may still show values (including the background sparkle line) when no metrics are received.  The larger graphs at the bottom will approrpriately show no value when IO stops (as reflected in the current column).

Some of the single stats will show as orange or red if thresholds are crossed.  For example, once ms latency crosses 5ms the latency quick stat will show orange and once ms latency crosses 10ms the latency will show red.  These are not meant to be absolute and should adjusted for your environment/requirements. 

Accurate time on both the client machine (web browser), the graphana server, and workers is appropriate for accurate stats.  NTP is recommended. Graph rendering is done by the client browser and if the local time is off on that machine, the graphs will show as skewed in time. 

The graphs are ideally setup for a single command vm with multiple workers.  It is expected that the command vm will control the execution of vdbench to the workers (ssh keys) and aggregate the stats to be fed to graphite.  There's no reason that  vdbench running indvidually on hosts (not controlled by a command) wouldn't also work, but some modification of the graphs would help.  For example, the table for IOPS could be modified to reflect the worker hostnames so each line can be clearly identified.  Also a separate line that totals all of the workers could show aggregate IOPS for all workers.  


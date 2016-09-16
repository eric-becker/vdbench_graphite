# vdbench_graphite
A bash script to feed parsed vdbench output to graphite with example grafana dashboard

![vdbench_graphite dashboard](https://cloud.githubusercontent.com/assets/2933063/18571124/8eab3210-7b75-11e6-83e4-de36763f1722.png "Logo Title Text 1")

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
```

By default stats will be sent to graphite running on localhost:2003 under vdbench.default.[HOSTNAME].[METRIC]  There are no required options, but additional parameters can be passed to change the destination host and/or port as well as a custom tag instead of using the hostname.  To implement multiple custom tags simply separate the tags with periods.  The -o option allows you to write the captured stdout to a file while still feeding graphite.

```
./vdbench -f foo.vdb -o outdir.foo | vdbench_graphite.sh -h server01 -p 2003 -t foo.baz -o console.foo
```

It is also possible to feed the stats from an existing vdbench workload provided stdout was written to a file. Simply cat the vdbench output file and redirect to vdbench_graphite.sh the same as above.  Note: original timestamps are used for the metrics so it will be necessary to look at the graph historically. 

```
cat console.foo | vdbench_graphite.sh -h server01 -p 2003 -t foo.baz 
```

Installing and configuring graphite and grafana are beyond the scope of this README.  As long as there is an appropriately configured storage schema for graphite, the graphs should look good.  If you notice gaps in the graphs verify that that the "interval=" parameter in your vdbench config matches the lowest retention period in storage-schemas.conf.  The easiest configuration (and highest granularity) is "interval=1" in the vdbench config and a stanza in storage-schemas.conf like:

```
[vdbench]
pattern = ^vdbench\.
retentions = 1s:7d, 5s:30d, 1m:90d
```

This will store metrics at 1 second granularity for 7 das, 5 second for 30 days, and 1 minute for 90 days.  Adjust as necessary for your needs. 

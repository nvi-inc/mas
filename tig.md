% Telegraf, InfluxDB and Grafana for VLBI Opertaions
% Dec 2016
% Dave Horsley <david.e.horsley@nasa.gov>

Introduction
============

The Telegraf, InfluxDB and Grafana tools provide a system for for collecting,
storing and visualizing time-series data.

The three component are loosely coupled and one can be easily swapped for an
alternative package. Other possible choices of time-series databases are
Promethius, Elasticsearch, OpenTSDB and others. Briefly, the role of components
are as follows:

![Data flow overview.](overview.pdf)


-   **Telegraf** collects data from different sources. Telegraf runs on
    every computer where you want to collect statistics. If it cannot
    access the database, it will buffer a configurable number
    of records. The standard version of Telegraf includes plugins for
    collecting data on things such as:
    -   disk usage
    -   system load
    -   network performance

    The VLBI branch, provided in the FS repository, contains plugins for:
    -   VLBI Field System
    -   Modbus Antennas (currently only Patriot 12m of the AuScope/GGAO generation)
    -   MET4 meteorological system
    -   RDBE multicast

-   **InfluxDB** is a time-series database. It offerers
    high-performance compression and retrieval. This can be at station
    or off-site. It is similar to relational databases you may be familiar
    with, but is far more efficient at handling time-series data.
    InfluxDB has an SQL like query language, but it is distinct and some
    concepts differ, so it is best to consider it as a new system. I will
    discuss this further down.

    Unlike some other monitoring systems, eg MoniCA or Prometheus, InfluxDB 
    is a push type model. This means the clients, ie. the programs with the data,
    initiate the connection to Influx. If you require a fetch model, Telegraf
    can be used as a bridge.

    Depending on the number of points you are monitoring, the load on the
    system it runs on can be fairly high. For this reason, it 
    is worth doing some tests and tuning if you wish to run it on your FS PC. If you 
    can afford it, it is best to run it on a separate machine.

-   **Grafana** provides the graphical user interface. It allows you to
    plot historical data, and build (near) real-time dashboards for any
    metrics that are being written to the database. Grafana should be
    run on a computer that can access InfluxDB server(s) and
    the computer(s) you want to monitor from. Grafana runs a web server
    and you connect to it via your web browser. I have found Google Chrome
    to give superior performance.

Each project is open-source with paid support.
[Grafana.net](https://grafana.net/support/) provide premium support for
Grafana and [InfluxData](https://influxdata.com/) provide the same
for Telegraf and InfluxDB. InfluxData also maintain the other open-source
packages Chronograf (similar to Grafana), and Kapacitor (used for alerts and
data processing). I will not cover these here, only because I have do not have
much experience with them, however both look promising. InfluxData also
maintain a commercial version of InfluxDB with cluster support and admin tools aimed
at larger scales.

I will focus on installation on Debian or Ubuntu based Linux systems; however,
these packages can run on different distributions and operating systems.


Installing
==========

A recommended setup:

-   On a server in a central location, install InfluxDB and Grafana.
    This sever should be accessible from all PCs you want to monitor and all
    PCs you want to monitor from. It does not need to be at the station or
    a computer you use for monitoring. 
-   On each computer you want to monitor, install Telegraf.

If you have multiple stations, you have some choices:

-   **Run a central database.** this is easier to setup and manage,
    as well as less expensive. All stations and client write to the
    single central database.
    
    Telegraf will tolerate network interruptions, to some extent, by holding
    the latest points in memory. The number of points it holds is configurable,
    so you can set it high enough to buffer an average outage. RAM/swap limited
    of course. If you write you own clients, they will need to do this
    themselves. Alternativly, there is also [InfluxDB-Relay], which can act as
    a simple relay for InfluxDB at the station. All clients write to this
    instead of the remote server, and it forwards them on if it can, and
    buffers them in memory if it can't. This may be a good option if you are
    concerned about some client running out of memory during an outage.

-   **Run a database at each station.** This has the advantage that if
    the network connection is lost, clients will continue to write to 
    the database. It is also advantageous if there are local operators
    that wish to look at the data. 
    
    This has the disadvantage that you will need a system capable of running
    the database and storing the data at each station. It may also be slow if
    you are querying the database remotely.


-   **Multiple databases.** The setup for this would be fairly involved,
    but you get the best of both options. If you don't want to store


  [InfluxDB-Relay]: https://github.com/influxdata/influxdb-relay


On the server
-------------

Installation can be managed through the systems package manager `apt`.
The commands in this section should be run as root.

Get InfluxData's GPG key

    curl -sL https://repos.influxdata.com/influxdb.key | apt-key add -

And Grafana's key

    curl https://packagecloud.io/gpg.key | apt-key add -

Next, add the repositories by creating the file:

```ini
/etc/apt/sources.list.d/tig.list
--------------------------------
## Grafana repo
## Use for all Debian/Ubuntu variants
deb https://packagecloud.io/grafana/stable/debian/ jessie main

## InfluxData repo
## Uncomment the appropriate line
## Wheezy
#deb https://repos.influxdata.com/debian wheezy stable
#
## Jessie
#deb https://repos.influxdata.com/debian jessie stable
#
## For Ubuntu, replace xenial with appropriate code name
#deb https://repos.influxdata.com/ubuntu xenial stable
```

Install the InfluxDB and Grafana

    apt-get update
    apt-get install influxdb grafana

InfluxDB will automatically start on boot.
To enable Grafana to start on boot:

-   For systemd distributions, ie. Ubuntu ≥ 15.04 or Debian ≥ 8 (jessie), use

        systemctl enable grafana-server

-   For older SysVinit based distributions use

        update-rc.d grafana-server defaults

Start the server

    service grafana-server start 


Clients
-------

On any PC you wish to install the VLBI branch of Telegraf, add the FS
repository by creating

```ini
/etc/apt/sources.list.d/lupus.list:
----------------------------------
deb http://user:name@lupus.gsfc.nasa.gov/fs/debian wheezy legacy
## For VGOS stations
# deb http://lupus.gsfc.nasa.gov/fs/debian wheezy vgos
```

Get my GPG key:

    apt-key adv --keyserver keys.gnupg.net --recv-keys 6E2CE741

then install the package
    
    apt-get install telegraf-vlbi

Telegraf is configured to run on startup.


Creating new collectors
=======================

There are a few ways to go about this.


Shell
-----

A very basic option is to use the `curl` program.

```sh
#!/bin/sh
##
DB=station
PRECISION=s # or [n,u,ms,s,m,h]

curl -i -XPOST \
    "http://localhost:8086/write?db=$DB&precision=$PRECISION"
    --data-binary\
    'weather,station=washington temperature=35 1465839830100400200'
```



Requirements
------------

Building from source:

-   Go 1.7

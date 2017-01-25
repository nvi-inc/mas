% TIG for VLBI
% Dave Horsley <david.e.horsley@nasa.gov>
% Jan 2017

Introduction
============

The Telegraf, InfluxDB and Grafana (TIG) tools provide a system for for
collecting, storing and visualizing time-series data. The three component are
loosely coupled and one can be easily swapped for an alternative package.
Briefly, the role of components are as follows:

![Data flow overview in the TIG suite.](figures/overview)

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
    -   Modbus Antennas (Patriot 12m of the AuScope/GGAO generation)
    -   MET4 meteorological system
    -   RDBE multicast

-   **InfluxDB** is a time-series database. It offerers
    high-performance compression and retrieval. It is similar to relational
    databases you may be familiar with, but is far more efficient at handling
    time-series data. InfluxDB has an SQL like query language, but it is
    distinct and some concepts differ, so it is best to consider it as a new
    system. I will discuss this more later.

    Unlike some other monitoring systems, eg MoniCA or Prometheus, InfluxDB 
    is a push type model. This means the clients, that is the programs with the data,
    initiate the connection to InfluxDB. If you require a fetch model where the
    storage tool collects data from clients, Telegraf can be used as a bridge.

    Depending on the number of points you are monitoring, the load on the
    system it runs on can be fairly high. For this reason, it 
    is worth doing some testing and tuning if you wish to run it on your FS PC. If you 
    can afford it, it is likely best to run it on a separate machine.

-   **Grafana** provides the graphical user interface. It allows you to
    plot historical data, and build (near) real-time dashboards for any
    metrics that are being written to the database. Grafana should be
    run on a computer that can access InfluxDB server(s) and
    the computer(s) you want to monitor from. Grafana runs a web server
    and you connect to it via your web browser. I have found Google Chrome
    to give superior performance.

Each project is open-source with paid support. [Grafana.net] provide premium
support for Grafana and [InfluxData] provide the same for Telegraf and
InfluxDB. InfluxData also maintain the other open-source packages Chronograf
(similar to Grafana), and Kapacitor (used for alerts and data processing).
I will not cover these here, only because I have do not have much experience
with them, however both look promising. InfluxData also maintain a commercial
version of InfluxDB with cluster support and admin tools aimed at larger
scales.

  [Grafana.net]: https://grafana.net/support/
  [InfluxData]: https://influxdata.com/

I will focus on installation on Debian or Ubuntu based Linux systems; however,
these packages can run on different distributions and operating systems.


## Remote operations considerations

If you have multiple station or monitor from a remote location,
you have a few choices of where to keep the database. If you do not,
you can skip to [Installation].


<!--
Note: Users do not strictly need to be inside the ops center, just the ability
to connect to the webserver on the Grafana pc. This could be locally, via VPN,
or via the Internet. Grafana has good access levels controls and HTTPS support,
so it is safe and convenient to leave open to the internet. 
-->

### Run a central database (Recommended)

This is easier to setup and manage, as well as less expensive. In this model,
all stations and client write to the single central database at the operations
center. See the figure


Telegraf will tolerate network interruptions, to some extent, by holding
the latest points in memory. The number of points it holds is configurable,
so you can set it high enough to buffer an average outage. RAM/swap limited
of course. 

![Single Centeral Database model. As in the introduction, red circles represent collectors; blue squares,
the database; green rounded squares, the database clients; and yellow pentagons, the user. Arrows indicate
the flow of data.](figures/opsdb)

If you write you own collector, you will need to do this yourself.
There is a program called [InfluxDB-Relay], which can proxy
collector's writes to the database. All clients write to the relay
instead of the remote server, which then forwards them on if it can, and
buffers them in memory if it can't. This may be a good option if you are
concerned about some client running out of memory during a network outage.

  [InfluxDB-Relay]: https://github.com/influxdata/influxdb-relay


![Decentralized model.](figures/stationdb)

### Run a database at each station

This has the advantage that if
the network connection is lost, clients will continue to write to 
their local database. It is also advantageous if there are local operators
that wish to look use the data.

This has the disadvantage that you will need a system capable of running
the database and storing the data at each station. It can also be slow when
you are querying the database remotely.

![Multiple Database model.](figures/multidb)

### Run databases at stations and control center 

The setup would be fairly involved, but you get the best of both options. You
can configure "retention" policies at the stations, so only a certain period of
records are kept there. [InfluxDB-Relay] can be use to write to local and
remote databases at the same time moderate small outages. For large outages,
a program would need to be run to sync the databases.

 


Installation
============

These instructions will cover a central database setup which consists of:

-   A **server** in a central location, which we will install **InfluxDB** and **Grafana**.
    This sever should be accessible from all PCs you want to monitor and all
    PCs you want to monitor from. It does not need to be at the station or
    a computer you use for monitoring. 

-   A collection of **client** computer you want to monitor, on
    which we will install **Telegraf**. 


On the server
-------------

[^note]

[^note]:{-} We assume you are running a Debian based system for your server. If
you are using a different distribution or operating system, follow installation
documentation for
[InfluxDB](https://docs.influxdata.com/influxdb/v1.1/introduction/installation/)
and [Grafana](http://docs.grafana.org/) 

Installation can be managed through the systems package manager `apt`.

The commands in this section should be run as root.

First we will setup the extra repositories. The repositories are signed so,
import InfluxData's and Grafana's key GPG keys:

    curl -sL https://repos.influxdata.com/influxdb.key | apt-key add -
    curl -sL https://packagecloud.io/gpg.key | apt-key add -

Add the repositories to the package manager by creating the file 
`/etc/apt/sources.list.d/tig.list`

```ini
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

Now install the InfluxDB and Grafana

    apt-get update
    apt-get install influxdb grafana

InfluxDB will be configured to automatically start on boot.

To enable Grafana to start on boot:

-   For newer systemd distributions, ie. Ubuntu ≥ 15.04 or Debian ≥ 8 (jessie), use

        systemctl daemon-reload
        systemctl enable grafana-server

-   For older SysVinit based distributions use

        update-rc.d grafana-server defaults

Start the server

    service grafana-server start 

InfluxDB and Grafana should now be installed and running on your server.

Clients
-------

On any PC you wish to install the VLBI branch of Telegraf, add the FS
repository by creating the file

    /etc/apt/sources.list.d/lupus.list

```ini
deb http://user:pass@lupus.gsfc.nasa.gov/fs/debian wheezy legacy
## For VGOS stations
# deb http://lupus.gsfc.nasa.gov/fs/debian wheezy vgos
```

where "user" and "pass" are your username and password for the GSFC Field System repository.

Get my (David Horsley) GPG key:

    apt-key adv --keyserver keys.gnupg.net --recv-keys 6E2CE741

then install the package

    apt-get install telegraf-vlbi

Telegraf is setup to run on startup. 

You will need to configure Telegraf. The VLBI branch of Telegraf come with
a range of useful plugins enabled. To view and modify Telegraf's configuration


Working directly with the database
----------------------------------

See InfluxDB [Getting Started](https://docs.influxdata.com/influxdb/v1.1/introduction/getting_started/)


Creating new collectors
=======================

InfluxDB takes in data over HTTP. This makes it easy to write client libraries with any programming language.

There is probably already a client library available for your favorite programming language. Have a look at the [list of client libraries]. 


  [list of client libraries]: https://docs.influxdata.com/influxdb/v1.1/tools/api_client_libraries/

Influx Line Protocol
--------------------

The Line Protocol is a text based format for writing points to InfluxDB. 
For a more detail overview see the [Documentaiton].

    <measurement>[,<tag_key>=<tag_value>,...] <field_key>=<field_value>[,...] [<timestamp>]

Each line, separated by the newline character `\n`, represents a single
point in InfluxDB. Line Protocol is whitespace sensitive.

  [Documentaiton]: https://docs.influxdata.com/influxdb/v1.1/write_protocols/line_protocol_reference/

###Line Protocol Elements

Line Protocol informs InfluxDB of the data's measurement, tag set, field set, and timestamp.

  ----------------------------------------------------------------------------------------------------------------------------
  Element             Optional/Required                      Description                 Type (See [data types] for more
                                                                                         information.)
  ------------------- -------------------------------------- --------------------------- -------------------------------------
  [Measurement]       Required                               The measurement name.       String
                                                             InfluxDB accepts one        
                                                             measurement per point.      

  [Tag set]           Optional                               All tag key-value pairs for [Tag keys] and [tag values] are both
                                                             the point.                  strings.

  [Field set]         Required. Points must have at least    All field key-value pairs   [Field keys] are strings. [Field
                      one field.                             for the point.              values] can be floats, integers,
                                                                                         strings, or booleans.

  [Timestamp]         Optional. InfluxDB uses the server's   The timestamp for the data  Unix nanosecond timestamp. Specify
                      local nanosecond timestamp in UTC if   point. InfluxDB accepts one alternative precisions with the [HTTP
                      the timestamp is not included with the timestamp per point.        API].
                      point.                                                             
  ----------------------------------------------------------------------------------------------------------------------------

  [data types]: #data-types
  [Measurement]:  https://docs.influxdata.com/influxdb/v1.1/concepts/glossary/#measurement
  [Tag set]: https://docs.influxdata.com/influxdb/v1.1/concepts/glossary/#tag-set
  [Tag keys]: https://docs.influxdata.com/influxdb/v1.1/concepts/glossary/#tag-key
  [tag values]: https://docs.influxdata.com/influxdb/v1.1/concepts/glossary/#tag-value
  [Field set]: https://docs.influxdata.com/influxdb/v1.1/concepts/glossary/#field-set
  [Field keys]: https://docs.influxdata.com/influxdb/v1.1/concepts/glossary/#field-key
  [Field values]: https://docs.influxdata.com/influxdb/v1.1/concepts/glossary/#field-value
  [Timestamp]: https://docs.influxdata.com/influxdb/v1.1/concepts/glossary/#timestamp
  [HTTP API]: https://docs.influxdata.com/influxdb/v1.1/tools/api/#write



Shell
-----

A very basic option is to use the `curl` program.

```sh
#!/bin/sh
##
DB=station
PRECISION=s # or [n,u,ms,s,m,h]; determines the meaning of the timestamp

URL="http://localhost:8086/write?db=$DB&precision=$PRECISION"

DATA='weather,station=washington temperature=35 pressure=1024.5 humidity=95.1 1484842058'

curl -i -XPOST $URL --data-binary $DATA
   
```

In this example, the timestamps are in unix time, ie number of seconds since
1970-01-01T00:00:00Z. This is determined by the precision. If precision is set to
something other than 


Go
---

[Go] has a client library written and supported by the InfluxDB team.

  [Go]: https://golang.org/

See [InfluxDB Client]

  [InfluxDB Client]: https://github.com/influxdata/influxdb/tree/master/client

To install

    go get github.com/influxdata/influxdb/client/v2

and to use

``` {.go}
import "github.com/influxdata/influxdb/client/v2"
```

See [weather log collector](./wth.go)


Python
------

See [InfluxDB-Python]. To install, use Python's package manager:

    pip install influxdb

For usage, see [InfluxDB-Python Examples].

  [InfluxDB-Python]: https://github.com/influxdata/influxdb-python
  [InfluxDB-Python Examples]: http://influxdb-python.readthedocs.io/en/latest/examples.html#tutorials-basic

Requirements
------------

Building from source:

-   Go 1.7

---
title: TIG for VLBI
author:
- 'Dave Horsley <david.e.horsley@nasa.gov>'
date: Feb 2017
---

Introduction
============

The Telegraf, InfluxDB and Grafana (TIG) tools provide a system for for
collecting, storing, and visualizing time-series data. The three
component are loosely coupled and one can be easily swapped for an
alternative package. Briefly, the role of components are as follows:

![Data flow overview in the TIG suite.](figures/overview)

-   **Telegraf** collects data from different sources. Telegraf runs on
    every computer where you want to collect statistics. If it cannot
    access the database, it will buffer a configurable number of
    records. The standard version of Telegraf includes plugins for
    collecting data on things such as:

    -   disk usage and load
    -   system load
    -   network load and performance
    -   process statistics
    -   and a large range of DevOps tools such as web, mail, and database servers; message queues; etc.

    The VLBI branch, provided in the FS repository, contains plugins
    for:

    -   The VLBI Field System
    -   Modbus Antennas (currently Patriot 12m of the AuScope/GGAO generation)
    -   MET4 meteorological system via `metserver`
    -   RDBE multicast

-   **InfluxDB** is a time-series database. It offerers high-performance
    compression and retrieval. It is similar to relational databases you
    may be familiar with, but is far more efficient at handling
    time-series data. While InfluxDB has an SQL-like query language, it
    is distinct and it is best to consider it as a new system.

    Unlike some other monitoring systems, eg MoniCA or Prometheus,
    InfluxDB is a push type model. This means the clients, the programs
    with the data, initiate the connection and write to the database. If
    you require a fetch model where the tool collects data from clients,
    Telegraf can be used as a bridge.

    Depending on the number of points you are monitoring, the load on
    the system it runs on can be fairly high. For this reason, it is
    worth doing some testing and tuning if you wish to run it on your FS
    PC. If you can, it is likely best to run it on a separate machine.

-   **Grafana** provides the graphical user interface. It allows you to
    plot historical data, and build (near) real-time dashboards for any
    metrics that are being written to the database. Grafana should be
    run on a computer that can access InfluxDB server(s) and the
    computer(s) you want to monitor from. Grafana runs a web server and
    you connect to it via your web browser. I have found Google Chrome
    to give superior performance.

Each project is open-source with paid support.
[Grafana.net](https://grafana.net/support/) provide premium support for
Grafana and [InfluxData](https://influxdata.com/) provide the same for
Telegraf and InfluxDB. InfluxData also maintain the other open-source
packages Chronograf (similar to Grafana), and Kapacitor (used for alerts
and data processing). I will not cover these here, only because I have
do not have much experience with them, however both look promising.
InfluxData also maintain a commercial version of InfluxDB with cluster
support and admin tools aimed at larger scales.

We will focus on installation on Debian or Ubuntu based Linux systems;
however, these packages can run on different distributions and operating
systems.


These instructions will cover setting up a central database which consists
of:

-   A **server** in a central location, which we will install
    **InfluxDB** and **Grafana**. This sever should be accessible from
    all PCs you want to monitor and all PCs you want to monitor from. It
    does not need to be at the station or a computer you use for monitoring.

-   A collection of **client** computer you want to monitor, on which we
    will install **Telegraf**.

![Example Setup. As in the introduction, red circles
represent collectors; blue square, the database; green rounded square,
the database clients; and yellow pentagons, the user interfaces. Arrows indicate
the flow of data.](figures/installation)

If you have multiple stations or monitor from a remote location, you have
a few choices of where to keep the database. For more complex models than
what we discuss here, see [Remote operations considerations]. The setup we
give here, as exampled in the figure, is easier to install and manage, as
well as less expensive.

In this model, Telegraf tolerate network interruptions, to some
extent, by holding the latest points in memory until it can write to the
database. This is the method used by Station 1 in Figure 2. The number of points
Telegraf holds is configurable, limited by RAM/swap, so you can set it high
enough to buffer an average outage. If you write you own collector, you
will need to do this yourself. We will give an example of this later.

There is also
[InfluxDB-Relay](https://github.com/influxdata/influxdb-relay), which can
proxy collector's writes to the database. This method is used by Station
2 in Figure 2. All clients write to the relay, which presents the same
interface as the database, which then forwards them on if it can, and
buffers them in memory if it can't. We will not cover setup of the relay here.


Server
======

Installation
------------

We assume you are running a Debian based system for your server. If you
are using a different distribution or operating system, follow
installation documentation for
[InfluxDB](https://docs.influxdata.com/influxdb/v1.1/introduction/installation/)
and [Grafana](http://docs.grafana.org/)

The commands in this section should be run as root.

Installation is managed through the systems package manager `apt` using
dedicated repositories. The repositories are signed so, first import
InfluxData's and Grafana's key GPG keys:

    curl -sL https://repos.influxdata.com/influxdb.key | apt-key add -
    curl -sL https://packagecloud.io/gpg.key | apt-key add -

Now add the repositories to the package manager by creating the file
`/etc/apt/sources.list.d/tig.list` with contents

``` {.ini}
###################
## Grafana repo
## Use for all Debian/Ubuntu variants
deb https://packagecloud.io/grafana/stable/debian/ jessie main

##################
## InfluxData repo
## Uncomment the appropriate line

## Wheezy
#deb https://repos.influxdata.com/debian wheezy stable
#
## Jessie
#deb https://repos.influxdata.com/debian jessie stable
#
## For Ubuntu, replace xenial with appropriate codename
## if you dont know this run:
##    source /etc/os-release && echo $VERSION
#deb https://repos.influxdata.com/ubuntu xenial stable
```

Now in a root shell install the InfluxDB and Grafana

    apt-get update
    apt-get install influxdb grafana

InfluxDB will be configured to automatically start on boot. To enable Grafana to start on boot:

-   For systemd based distributions, ie. Ubuntu ≥ 15.04 or Debian ≥ 8
    (jessie), use

        systemctl daemon-reload
        systemctl enable grafana-server

    And start the server

        systemctl start grafana-server

-   For older SysVinit based distributions use

        update-rc.d grafana-server defaults

    And start the server

        service grafana-server start
        # or /etc/init.d/grafana-server start


InfluxDB and Grafana should now be installed and running on your server.

If you like, you can also install Telegraf on your this. This is useful
for monitoring disk usage and load. If you don't need the VLBI fork, you
can run `apt-get install telegraf` to get the standard version from the
InfluxData repository.

You should now be able to access Grafana by entering
`http://<server address>:3000` in a web browser. InfluxDB
is also running an HTTP server on `<server address>:8083`, but you will not
see anything there with browser.

Configuration
-------------

###Grafana
*For a complete overview Grafana's configuration see the [official
documentation](http://docs.grafana.org/installation/configuration/)*

Grafana's configuration is located in `/etc/grafana/grafana.ini`.  To begin
with, you will not need to change this. 


###InfluxDB
*For a complete overview InfluxDB's configuration see the [official
documentation](https://docs.influxdata.com/influxdb/v1.2/administration/config/)*

InfluxDB's configuration is located in `/etc/influxdb/influxdb.conf`.
The one thing variable you may need to change is the location of the permanent storage.
By default, this is set to `/var/lib/influxdb/data`.
If this is not acceptable, it can be changed by setting
the `dir` variable of section `[data]`. 

### HTTPS and Nginx (advanced)

See Appendix

If you wish to open your Grafana server to the Internet, it is advisable to configure HTTPS

Clients
=======

Installation
------------

On any PC you wish to install the VLBI branch of Telegraf, for example
your Field System PC, add the FS repository by creating the file
`/etc/apt/sources.list.d/lupus.list`

    deb http://user:pass@lupus.gsfc.nasa.gov/fs/debian wheezy main

where "user" and "pass" are your username and password for the GSFC
Field System repository.

Get David Horsley's GPG key:

    apt-key adv --keyserver keys.gnupg.net --recv-keys 6E2CE741

then install the package

    apt-get install telegraf-vlbi

Telegraf is setup to run on startup.

Configuration
-------------

The VLBI branch of Telegraf come with a range of useful plugins
enabled by default, but you will need to set a few variables.
This is done by editing the file `/etc/telegraf/telegraf.conf`.

The first item is **Global tags**. These are tags that are added all
measurements collected. It's recommended you at-least
add a tag for the station. Do this by finding the line

    # Global tags can be specified here in key="value" format.
    [global_tags]

and add, eg,

    station="gs"


Next you will find the general **Telegraf agent** configuration, beginning with

``` {.ini}
# Configuration for telegraf agent
[agent]
  ## Default data collection interval for all inputs
  interval = "10s"
```

This sets the default period for all collectors. If you're happy with a
10s default period leave this as is. This can be overridden on
an input by input basis.

Now configure the **InfluxDB Output**

``` {.ini}
#Configuration for influxdb server to send metrics to
[[outputs.influxdb]]
...
    urls = ["http://localhost:8086"]
```

and change `localhost` to the address (IP or DNS name) of your server
setup in the previous section. In the same section you will also find a
line specifying database:

``` {.ini}
    database = "vlbi"
```

It is OK to leave it as this default. If you are configuring the
standard Telegraf installation (non-VLBI) you should change this to
match the above.

This completes the necessary configuration set of Telegraf, however you
likely want to enable some extra inputs

### Telegraf inputs

*For full details on configuring Telegraf, see the [official documentation]*


The default configuration file for Telegraf has a set of basic PC health
input plugins such as CPU usage, Disk usage, Disk IO, Kernel
stats, Memory usage, Processes stats, and swap usage.

To enable more specific plugins, uncomment them in `/etc/telegraf/telegraf.conf`.

For example, on your Field System PC, you will likely want to enable the Field System
collector so find the `[[inputs.fieldsystem]]` section in `telegraf.conf` and
remove the `#` prefix, ie

```ini
# Poll the Field System state through shared memory.
[[inputs.fieldsystem]]
  ## Rate to poll shared memory variables
  # precision = "100ms"
  ## Collect RDBE phasecal and tsys
  # rdbe = false
```

You do not need to uncomment the settings unless you want to change the
indicated default.

If you would like to enable the metserver collector, uncomment the `[[intpus.met4]]`
section. You can also may also like to add extra tags and set a custom poll interval,
e.g.:

```ini
# Query a MET4 meteorological measurements systems via metserver
[[inputs.met4]]
  ## Address of metserver
  address = "127.0.0.1:50001"
  interval = "1m"
  [inputs.met4.tags]
    location = "tower"
```


[official documentation]: https://docs.influxdata.com/telegraf/v1.2/administration/configuration/

Working the Database
====================

See InfluxDB
[Getting Started](https://docs.influxdata.com/influxdb/v1.1/introduction/getting_started/)

Since InfluxDB is a time-series database, its data model is different to
relational (SQL) databases.

The fundamental structure is a Point, which consists which consists of

    name: census
    -----------------
    time                           butterflies   honeybees   location    scientist
    2015-08-18T00:00:00Z     1                30               1               perpetua

Creating new collectors
=======================

InfluxDB takes in data over HTTP. This makes it easy to write client
libraries with any programming language.

There is probably already a client library available for your favorite
programming language. Have a look at the [list of client libraries](https://docs.influxdata.com/influxdb/v1.1/tools/api_client_libraries/).

Influx Line Protocol
--------------------

The Line Protocol is a text based format for writing points to InfluxDB.
For a more detail overview see the
[Documentaiton](https://docs.influxdata.com/influxdb/v1.1/write_protocols/line_protocol_reference/).

    <measurement>[,<tag_key>=<tag_value>,...] <field_key>=<field_value>[,...] [<timestamp>]

Each line, separated by the newline character `\n`, represents a single
point in InfluxDB. Line Protocol is whitespace sensitive.

### Line Protocol Elements

Line Protocol informs InfluxDB of the data's measurement, tag set, field
set, and timestamp.

  ----------------------------------------------------------------------------------------------------------------------
  Element             Optional/Required                    Description                Type (See [data types] for more
                                                                                      information.)
  ------------------- ------------------------------------ -------------------------- ----------------------------------
  [Measurement]       Required                             The measurement name.      String
                                                           InfluxDB accepts one
                                                           measurement per point.

  [Tag set]           Optional                             All tag key-value pairs    [Tag keys] and [tag values] are
                                                           for the point.             both strings.

  [Field set]         Required. Points must have at least  All field key-value pairs  [Field keys] are strings. [Field
                      one field.                           for the point.             values] can be floats, integers,
                                                                                      strings, or booleans.

  [Timestamp]         Optional. InfluxDB uses the server's The timestamp for the data Unix nanosecond timestamp. Specify
                      local nanosecond timestamp in UTC if point. InfluxDB accepts    alternative precisions with the
                      the timestamp is not included with   one timestamp per point.   [HTTP API].
                      the point.
  ----------------------------------------------------------------------------------------------------------------------

  [data types]: #data-types
  [Measurement]: https://docs.influxdata.com/influxdb/v1.2/concepts/glossary/#measurement
  [Tag set]: https://docs.influxdata.com/influxdb/v1.2/concepts/glossary/#tag-set
  [Tag keys]: https://docs.influxdata.com/influxdb/v1.2/concepts/glossary/#tag-key
  [tag values]: https://docs.influxdata.com/influxdb/v1.2/concepts/glossary/#tag-value
  [Field set]: https://docs.influxdata.com/influxdb/v1.2/concepts/glossary/#field-set
  [Field keys]: https://docs.influxdata.com/influxdb/v1.2/concepts/glossary/#field-key
  [Field values]: https://docs.influxdata.com/influxdb/v1.2/concepts/glossary/#field-value
  [Timestamp]: https://docs.influxdata.com/influxdb/v1.2/concepts/glossary/#timestamp
  [HTTP API]: https://docs.influxdata.com/influxdb/v1.2/tools/api/#write

Shell
-----

A very basic option is to use the `curl` program.

``` {.sh}
#!/bin/sh
##
DB=station
PRECISION=s # or [n,u,ms,s,m,h]; determines the meaning of the timestamp

URL="http://localhost:8086/write?db=$DB&precision=$PRECISION"

DATA='weather,station=washington temperature=35 pressure=1024.5 humidity=95.1 1484842058'

curl -i -XPOST $URL --data-binary $DATA

```

This writes a point to of measurement type "weather" with tag "station" set to
"washington" fields "temperature", "pressure" and "humidity" set to floating
point values at the time `2017-01-19T16:07:38+00:00` (1484842058 unix time)

In this example, the time stamps are in UNIX time (seconds since
1970-01-01T00:00:00Z, not counting leap seconds). The meaning of the
time stamp is is determined by the `PRECISION` variable which has been
set to "s" for seconds. If, for example `PRECISION` is set to `n` for
nanoseconds (the default), the time stamp is interpreted as UNIX nano
seconds. In general it is best to use the lowest precision you can, as this improves
the performance of the database and compression.

Go
--

[Go] has a client library written and supported by the InfluxDB team.

See [InfluxDB Client]

To install

    go get github.com/influxdata/influxdb/client/v2

and to use

``` {.go}
import "github.com/influxdata/influxdb/client/v2"
```

See [weather log collector]

  [Go]: https://golang.org/
  [InfluxDB Client]: https://github.com/influxdata/influxdb/tree/master/client
  [weather log collector]: ./wth.go


Python
------

There is a mature Python library for dealing with InfluxDB connections at [InfluxDB-Python]. To install, use Python's package manager (probably as root):

    pip install influxdb


```python
import time
from requests.exceptions import ConnectTimeout
from influxdb import InfluxDBClient, SeriesHelper
from influxdb.exceptions import InfluxDBClientError, InfluxDBServerError

# Number of points to keep in buffer before discarding old points
MAX_BUFFER_SIZE = 1000
# Period length between measurments (seconds)
POLL_RATE = 10
# Measurement name
MEASUREMENT = "weather"

# DB settings
HOST = '127.0.0.1'
USERNAME = 'user'
PASSWORD = 'metricsmetricsmetrics'
DATABASE = 'vlbi'
TIMEOUT = 5 # seconds
PRECISION = 's'



class Point(SeriesHelper):
    class Meta:
        series_name = MEASUREMENT
        tags = ['station']
        fields = ['temperature', 'pressure', 'humitity']

    # Override SeriesHelper method as it doesn't allow precision other
    # than 'ns'. Setting a larger value for precision improves DB performance
    @classmethod
    def commit(cls, client=None):
        if not client:
            client = cls._client
        rtn = client.write_points(points=cls._json_body_(),
                                  time_precision=PRECISION)
        cls._reset_()
        return rtn


def main():
    client = InfluxDBClient(
        host=HOST,
        username=USERNAME,
        password=PASSWORD,
        database=DATABASE,
        timeout=TIMEOUT,
        )

    while True:
        #
        # Take measurements...
        #

        Point(station='washington',
              temperature=35,
              pressure=1024.5,
              humidity=95.1,
              )
        try:
            MciSeriesHelper.commit(client)
        except (ConnectTimeout, InfluxDBClientError, InfluxDBServerError) as e:
            # Points are held in queue
            print(e)

        if len(Point._datapoints[MEASUREMENT]) > MAX_BUFFER_SIZE:
            Point._datapoints[MEASUREMENT].pop(0)

        time.sleep(10)

if __name__ == "__main__":
    main()
```


For usage, see [InfluxDB-Python Examples].


  [InfluxDB-Python]: https://github.com/influxdata/influxdb-python
  [InfluxDB-Python Examples]: http://influxdb-python.readthedocs.io/en/latest/examples.html#tutorials-basic

Requirements
------------

Building from source:

-   Go 1.7


Remote operations considerations
================================

If you have multiple station or monitor from a remote location, you have
a few choices of where to keep the database. If you do not, you can skip
to [Installation](#installation).

<!--
Note: Users do not strictly need to be inside the ops center, just the ability
to connect to the webserver on the Grafana pc. This could be locally, via VPN,
or via the Internet. Grafana has good access levels controls and HTTPS support,
so it is safe and convenient to leave open to the internet.
-->

### Run a central database (Recommended)

This is easier to setup and manage, as well as less expensive. In this
model, all stations and client write to the single central database at
the operations center. See the figure

Telegraf will tolerate network interruptions, to some extent, by holding
the latest points in memory. The number of points it holds is
configurable, so you can set it high enough to buffer an average outage.

![Single Centeral Database model. As in the introduction, red circles
represent collectors; blue squares, the database; green rounded squares,
the database clients; and yellow pentagons, the user. Arrows indicate
the flow of data.](figures/opsdb)

If you write you own collector, you will need to do this yourself. There
is a program called
[InfluxDB-Relay](https://github.com/influxdata/influxdb-relay), which
can proxy collector's writes to the database. All clients write to the
relay instead of the remote server, which then forwards them on if it
can, and buffers them in memory if it can't. This may be a good option
if you are concerned about some client running out of memory during a
network outage.

![Decentralized model.](figures/stationdb)

### Run a database at each station

This has the advantage that if the network connection is lost, clients
will continue to write to their local database. It is also advantageous
if there are local operators that wish to look use the data.

This has the disadvantage that you will need a system capable of running
the database and storing the data at each station. It can also be slow
when you are querying the database remotely.

![Multiple Database model.](figures/multidb)

### Run databases at stations and control center

The setup would be fairly involved, but you get the best of both
options. You can configure "retention" policies at the stations, so only
a certain period of records are kept there.
[InfluxDB-Relay](https://github.com/influxdata/influxdb-relay) can be
use to write to local and remote databases at the same time moderate
small outages. For large outages, a program would need to be run to sync
the databases.

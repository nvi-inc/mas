#!/usr/bin/env python

import time
from requests.exceptions import ConnectTimeout
from influxdb import InfluxDBClient, SeriesHelper
from influxdb.exceptions import InfluxDBClientError, InfluxDBServerError

# DB settings
HOST = '127.0.0.1'
USERNAME = 'user'
PASSWORD = 'metricsmetricsmetrics'
DATABASE = 'vlbi'
TIMEOUT = 5  # seconds
PRECISION = 's'

# Number of points to keep in buffer before discarding old points
MAX_BUFFER_SIZE = 1000
# Period length between measurments (seconds)
POLL_RATE = 10
# Measurement name
MEASUREMENT = "weather"


class Points(SeriesHelper):
    class Meta:
        series_name = MEASUREMENT
        tags = ['station']
        fields = ['temperature', 'pressure', 'humitity']

    # Override SeriesHelper method as it doesn't allow precision other
    # than 'ns'. Setting a larger value for precision improves DB performance
    @classmethod
    def commit(cls, client):
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

        # Add point to queue
        Points(station='washington',
               temperature=35,
               pressure=1024.5,
               humidity=95.1,
              )

        # Try to write to database. This will raise an error if the
        # database is inaccessible and the queue will remain intact.
        try:
            Points.commit(client)
        except (ConnectTimeout, InfluxDBClientError, InfluxDBServerError) as e:
            print(e)

        # If the points queue is too full, start to removed older points
        # from the end so we won't run out of memory
        while len(Points._datapoints[MEASUREMENT]) > MAX_BUFFER_SIZE:
            Points._datapoints[MEASUREMENT].pop(0)

        time.sleep(POLL_RATE)

if __name__ == "__main__":
    main()

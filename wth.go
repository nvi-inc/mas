// InfluxDB wx log parser
// Reads log files from stdin and writes to the DB
//
// Update constants to configure
//
// usage:
//    cat /usr2/log/*.log | ./wth
//    # or
//    ssh pcfs 'cat /usr2/log/*.log' | ./wth
package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/influxdata/influxdb/client/v2"
)

const (
	ADDR      = "http://localhost:8086" // address of InfluxDB
	DB        = "vlbi"                  // database to write to
	USERNAME  = "telegraf"              // db username
	PASSWORD  = "pass"                  // db password
	BATCHSIZE = 1000                    // batch size to write to db
	PRECISION = "s"                     // precision of series

	AGENT = "wx" // Name of HTTP agent, useful for debuggin in db logs
)

// Extra tags
var tags map[string]string = map[string]string{
	"station": "ggao",
}

var wg sync.WaitGroup

// Parse an FS log time to native go type
// Input format is
// 2017.012.00:01:00.00
// ==
// yyyy.doy.HH:MM:SS:MS
func fsdate(s string) time.Time {
	fields := strings.SplitN(s, ".", 3)
	year, _ := strconv.Atoi(fields[0])
	doy, _ := strconv.Atoi(fields[1])
	t, _ := time.Parse("15:04:05.00", fields[2])
	return t.AddDate(year, 0, doy-1)
}

func ParseLine(line string) *client.Point {
	if line == "" {
		return nil
	}
	s := strings.Split(strings.TrimSpace(line), "/")
	if len(s) < 3 {
		return nil
	}
	t := fsdate(s[0])
	fieldvals := strings.Split(s[2], ",")
	fieldsnames := []string{
		"temperature",
		"pressure",
		"humidity",
		"windspeed",
		"windheading",
	}

	fields := make(map[string]interface{})
	for i, f := range fieldvals {
		v, err := strconv.ParseFloat(f, 64)
		if err != nil {
			continue
		}
		fields[fieldsnames[i]] = v
	}
	pt, err := client.NewPoint("met", tags, fields, t)
	if err != nil {
		return nil
	}
	return pt
}

func collector() chan<- *client.Point {
	points := make(chan *client.Point)
	influxcli, err := client.NewHTTPClient(client.HTTPConfig{
		Addr:      ADDR,
		UserAgent: AGENT,
		Username:  USERNAME,
		Password:  PASSWORD,
	})
	if err != nil {
		panic(err)
	}

	wg.Add(1)
	go func() {
		defer wg.Done()
		bp, err := client.NewBatchPoints(client.BatchPointsConfig{
			Database:  DB,
			Precision: PRECISION,
		})
		if err != nil {
			panic(err)
		}
		for pt := range points {
			bp.AddPoint(pt)
			if len(bp.Points()) > BATCHSIZE {
				err = influxcli.Write(bp)
				if err != nil {
					log.Printf("Error flushing: %v. Holding %d points", err, len(bp.Points()))
					continue
				}
				bp, err = client.NewBatchPoints(client.BatchPointsConfig{
					Database:  DB,
					Precision: PRECISION,
				})
				if err != nil {
					panic(err)
				}
			}
		}
		err = influxcli.Write(bp)
		if err != nil {
			log.Printf("Error on final flush: %v", err)
		}
	}()
	return points
}

func testcollector() chan<- *client.Point {
	points := make(chan *client.Point)
	go func() {
		for pt := range points {
			fmt.Println(pt)
		}
	}()
	return points
}

func main() {
	reader := bufio.NewReader(os.Stdin)
	points := collector()
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			break
		}
		pt := ParseLine(line)
		if pt == nil {
			continue
		}
		points <- pt
	}
	close(points)
	wg.Wait()
}

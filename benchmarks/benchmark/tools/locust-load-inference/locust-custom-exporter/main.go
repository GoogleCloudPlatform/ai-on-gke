package main

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"net/url"
	"os"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/prometheus/common/log"
	"github.com/prometheus/common/version"
	"gopkg.in/alecthomas/kingpin.v2"
)

var (
	namespace string
	NameSpace *string
)

// Exporter structure
type Exporter struct {
	uri   string
	mutex sync.RWMutex
	fetch func(endpoint string) (io.ReadCloser, error)

	locustAvgTokensSent,
	locustAvgTokensReceived,
	locustAvgTestTime,
	locustAvgOutputTokenLatency,
	locustTimeToFirstToken prometheus.Gauge
}

// NewExporter function
func NewExporter(uri string, timeout time.Duration) (*Exporter, error) {
	u, err := url.Parse(uri)
	if err != nil {
		return nil, err
	}

	var fetch func(endpoint string) (io.ReadCloser, error)
	switch u.Scheme {
	case "http", "https", "file":
		fetch = fetchHTTP(uri, timeout)
	default:
		return nil, fmt.Errorf("unsupported scheme: %q", u.Scheme)
	}

	return &Exporter{
		uri:   uri,
		fetch: fetch,
		locustAvgTokensSent: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Namespace: namespace,
				Subsystem: "custom_metrics",
				Name:      "avg_tokens_sent",
			},
		),
		locustAvgTokensReceived: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Namespace: namespace,
				Subsystem: "custom_metrics",
				Name:      "avg_tokens_received",
			},
		),
		locustAvgTestTime: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Namespace: namespace,
				Subsystem: "custom_metrics",
				Name:      "avg_test_time",
			},
		),
		locustAvgOutputTokenLatency: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Namespace: namespace,
				Subsystem: "custom_metrics",
				Name:      "avg_output_token_latency",
			},
		),
		locustTimeToFirstToken: prometheus.NewGauge(
			prometheus.GaugeOpts{
				Namespace: namespace,
				Subsystem: "custom_metrics",
				Name:      "avg_time_to_first_token",
			},
		),
	}, nil
}

// Describe function of Exporter
func (e *Exporter) Describe(ch chan<- *prometheus.Desc) {
	e.mutex.Lock()
	defer e.mutex.Unlock()

	ch <- e.locustAvgTokensSent.Desc()
	ch <- e.locustAvgTokensReceived.Desc()
	ch <- e.locustAvgTestTime.Desc()
	ch <- e.locustAvgOutputTokenLatency.Desc()
	ch <- e.locustTimeToFirstToken.Desc()
}

// Collect function of Exporter
func (e *Exporter) Collect(ch chan<- prometheus.Metric) {
	e.mutex.Lock()
	defer e.mutex.Unlock()

	var locustStats locustStats

	body, err := e.fetch("/stats/custom_metrics")
	if err != nil {
		log.Errorf("Can't scrape Pack: %v", err)
		return
	}
	defer body.Close()

	bodyAll, err := ioutil.ReadAll(body)
	if err != nil {
		return
	}

	_ = json.Unmarshal([]byte(bodyAll), &locustStats)

	ch <- prometheus.MustNewConstMetric(e.locustAvgTokensSent.Desc(), prometheus.GaugeValue, float64(locustStats.AvgTokensSent))
	ch <- prometheus.MustNewConstMetric(e.locustAvgTokensReceived.Desc(), prometheus.GaugeValue, float64(locustStats.AvgTokensReceived))
	ch <- prometheus.MustNewConstMetric(e.locustAvgTestTime.Desc(), prometheus.GaugeValue, float64(locustStats.AvgTestTime))
	ch <- prometheus.MustNewConstMetric(e.locustAvgOutputTokenLatency.Desc(), prometheus.GaugeValue, float64(locustStats.AvgOutputTokenLatency))
	ch <- prometheus.MustNewConstMetric(e.locustTimeToFirstToken.Desc(), prometheus.GaugeValue, float64(locustStats.AvgTimeToFirstToken))
}

type locustStats struct {
	AvgTokensSent         float64 `json:"average-tokens-sent"`
	AvgTokensReceived     float64 `json:"average-tokens-received"`
	AvgTestTime           float64 `json:"average-test-time"`
	AvgOutputTokenLatency float64 `json:"average-output-token-latency"`
	AvgTimeToFirstToken   float64 `json:"average-time-to-first-token"`
}

func fetchHTTP(uri string, timeout time.Duration) func(endpoint string) (io.ReadCloser, error) {
	tr := &http.Transport{TLSClientConfig: &tls.Config{InsecureSkipVerify: true}}
	client := http.Client{
		Timeout:   timeout,
		Transport: tr,
	}

	return func(endpoint string) (io.ReadCloser, error) {
		resp, err := client.Get(uri + endpoint)
		if err != nil {
			return nil, err
		}
		if !(resp.StatusCode >= 200 && resp.StatusCode < 300) {
			resp.Body.Close()
			return nil, fmt.Errorf("HTTP status %d", resp.StatusCode)
		}
		return resp.Body, nil
	}
}

func main() {
	var (
		listenAddress = kingpin.Flag("web.listen-address", "Address to listen on for web interface and telemetry.").Default(":8080").Envar("locust_custom_exporter_WEB_LISTEN_ADDRESS").String()
		metricsPath   = kingpin.Flag("web.telemetry-path", "Path under which to expose metrics.").Default("/metrics").Envar("locust_custom_exporter_WEB_TELEMETRY_PATH").String()
		uri           = kingpin.Flag("locust.uri", "URI of Locust.").Default("http://localhost:8089").Envar("locust_custom_exporter_URI").String()
		NameSpace     = kingpin.Flag("locust.namespace", "Namespace for prometheus metrics.").Default("locust").Envar("LOCUST_METRIC_NAMESPACE").String()
		timeout       = kingpin.Flag("locust.timeout", "Scrape timeout").Default("5s").Envar("locust_custom_exporter_TIMEOUT").Duration()
	)

	log.AddFlags(kingpin.CommandLine)
	kingpin.Version(version.Print("locust_exporter"))
	kingpin.HelpFlag.Short('h')
	kingpin.Parse()

	namespace = *NameSpace
	log.Infoln("Starting locust_custom_exporter", version.Info())
	log.Infoln("Build context", version.BuildContext())

	exporter, err := NewExporter(*uri, *timeout)
	if err != nil {
		log.Fatal(err)
	}
	prometheus.MustRegister(exporter)
	prometheus.MustRegister(version.NewCollector("locustexporter"))

	http.Handle(*metricsPath, promhttp.Handler())
	http.HandleFunc("/quitquitquit", func(http.ResponseWriter, *http.Request) { os.Exit(0) })
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`<html><head><title>Locust Exporter</title></head><body><h1>Locust Exporter</h1><p><a href='` + *metricsPath + `'>Metrics</a></p></body></html>`))
	})

	log.Infoln("Listening on", *listenAddress)
	log.Fatal(http.ListenAndServe(*listenAddress, nil))
}

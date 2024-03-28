# Locust Exporter

Prometheus exporter for [Locust](https://github.com/locustio/locust). This exporter was inspired by [containersol/locust_exporter](https://github.com/ContainerSolutions/locust_exporter/tree/main) and added on to for collecting Inferencing Benchmarking custom metrics.

## Build Locust Exporter

With Docker:

    ```bash
    docker build --tag locust-custom-exporter .
    ```

### Flags

- `--locust.uri`
  Address of Locust. Default is `http://localhost:8089`.

- `--locust.timeout`
  Timeout request to Locust. Default is `5s`.

- `--web.listen-address`
  Address to listen on for web interface and telemetry. Default is `:8080`.

- `--web.telemetry-path`
  Path under which to expose metrics. Default is `/metrics`.

- `--locust.namespace`
  Namespace for prometheus metrics. Default `locust`.

- `--log.level`
  Set logging level: one of `debug`, `info`, `warn`, `error`, `fatal`

- `--log.format`
  Set the log output target and format. e.g. `logger:syslog?appname=bob&local=7` or `logger:stdout?json=true`
  Defaults to `logger:stderr`.

### Environment Variables

The following environment variables configure the exporter:

- `LOCUST_EXPORTER_URI`
  Address of Locust. Default is `http://localhost:8089`.

- `LOCUST_EXPORTER_TIMEOUT`
  Timeout reqeust to Locust. Default is `5s`.

- `LOCUST_EXPORTER_WEB_LISTEN_ADDRESS`
  Address to listen on for web interface and telemetry. Default is `:8080`.

- `LOCUST_EXPORTER_WEB_TELEMETRY_PATH`
  Path under which to expose metrics. Default is `/metrics`.

- `LOCUST_METRIC_NAMESPACE`
  Namespace for prometheus metrics. Default `locust`.

## License

Apache License. Please see [License File](LICENSE.md) for more information.

# arith-ruby

arith does integer arithmetic over HTTP. Four endpoints, a page that calls them, Prometheus on `/metrics`. One Ruby process, Rails in API-only mode on Puma, on port 8000. Traces and logs go over OTLP if you set the usual `OTEL_*` variables; otherwise they stay on stdout.

Helm and Kustomize both install a Deployment and a ClusterIP Service. The default install works on a cluster that has nothing else: no ingress controller, no special CNI, no operator.

I run one at <https://arith.giovanni.dev.br>. The values for that cluster are in `deploy/examples/arith.giovanni.dev.br.yaml`. The same contract is also implemented in Rust, <https://github.com/giovannirco/arith-rust>, and in TypeScript, <https://github.com/giovannirco/arith-ts>.

## API

| Request | Response |
|---|---|
| `GET /api/sum?term_one=4&term_two=1` | `200 {"result":5}` |
| `GET /api/sub?term_one=4&term_two=1` | `200 {"result":3}` |
| `GET /api/mul?term_one=4&term_two=1` | `200 {"result":4}` |
| `GET /api/div?term_one=7&term_two=2` | `200 {"result":3}` |
| `GET /api/div?term_one=1&term_two=0` | `400 {"error":"division by zero"}` |
| `GET /api/sum?term_one=abc&term_two=1` | `400 {"error":"term_one must be an integer, got \"abc\""}` |
| `GET /api/sum?term_one=1` | `400 {"error":"term_two is required"}` |
| `GET /api/sum?term_one=9223372036854775807&term_two=1` | `400 {"error":"result does not fit in a 64-bit integer"}` |
| `GET /healthz` | `200 {"status":"ok"}` |
| `GET /metrics` | `200`, Prometheus text format |
| `GET /` | `200`, the page |

### Decisions

- Terms and results are signed 64-bit integers. Ruby's integers never overflow, so the range is checked on every term and every result. `1.5` is rejected, not rounded. A term that looks like an integer but does not fit gets its own message: `term_one does not fit in a 64-bit integer, got "..."`.
- A term is an optional sign and decimal digits, nothing else: `010` is ten, and `0x1f`, `1_000` and ` 5` are rejected, although Ruby's `Integer()` would take them.
- Division truncates toward zero: `7/2 = 3`, `-7/2 = -3`. Ruby's own `/` rounds down (`-7/2` is `-4` in Ruby), so `div` does not use it as is. Dividing by zero is a `400`.
- A result outside the 64-bit range is a `400`, not a bigger number.
- Every error is JSON, `{"error":"..."}`, and the text says what was wrong with which parameter. An unknown path is `404 {"error":"not found"}`. A method other than GET is `405 {"error":"method not allowed"}`. A query string with bytes that are not UTF-8 is `400 {"error":"bad request"}`.
- In a query string `+` is a space, so `term_two=+2` is rejected. Send `%2B2`, or just `2`.
- `/healthz` is the only health URL. Liveness and readiness both use it.

## The page

`GET /` is one screen from the same process: two fields, four operations, the result, and the error text when the API refuses a call. No frontend build, no second container. The page asks the API for every result. It does not compute anything itself.

Locally that is <http://localhost:8000>. In a cluster the Service is ClusterIP, so a person opens it with `kubectl port-forward`. Other workloads call the Service directly.

## Run it here

You need Ruby 4.0 and Bundler ([ruby-lang.org](https://www.ruby-lang.org/en/documentation/installation/)), or just Docker. `.ruby-version` names the exact Ruby CI and the image use.

```sh
bundle install
make test     # unit tests and the HTTP contract
make cover    # the same, with a line coverage report (SimpleCov)
make run      # serve on :8000 with readable logs
make image    # docker build, tag 1
```

`make cover` prints the line coverage of `app/`, `lib/` and `config/` and writes `coverage/index.html`. The suite covers the worked example, truncation in both signs, division by zero, missing and non-integer terms, overflow in every operation, the error bodies, the page and its assets, the metrics, the access log, the spans, the exporter wiring, and a real Puma process that serves, drains on SIGTERM and refuses a bad setting.

## Configuration

Everything is an environment variable. `ARITH_*` belong to this program. `OTEL_*` are the [OpenTelemetry names](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/), so a collector's documentation applies as written. A value the program cannot use stops it at start, with a message naming the variable.

| Variable | Default | Meaning |
|---|---|---|
| `ARITH_ADDR` | `0.0.0.0:8000` | Listen address, `host:port` (`[::]:8000` for IPv6) |
| `ARITH_LOG_LEVEL` | `info` | `debug`, `info`, `warn` or `error` |
| `ARITH_LOG_FORMAT` | `json` | `json` or `text` |
| `ARITH_SHUTDOWN_TIMEOUT` | `10` | Seconds to let requests finish after SIGTERM |
| `OTEL_TRACES_EXPORTER` | `none` | `otlp` sends one span per request |
| `OTEL_LOGS_EXPORTER` | `console` | `console`, `otlp`, `console,otlp` or `none` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` | The only transport Ruby's OTLP exporters have; `grpc` is refused |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` | Where OTLP goes. `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` and `OTEL_EXPORTER_OTLP_LOGS_ENDPOINT` override it per signal |
| `OTEL_SERVICE_NAME` | `arith` | `service.name` on every span and log record |
| `OTEL_TRACES_SAMPLER`, `OTEL_TRACES_SAMPLER_ARG` | `parentbased_always_on` | e.g. `parentbased_traceidratio` and `0.1` |
| `OTEL_EXPORTER_OTLP_HEADERS` | | `key=value,...`, for tenancy or auth headers |
| `SECRET_KEY_BASE` | random per process | Rails asks for one in production. Nothing here is signed or encrypted, so there is nothing to set |

The image sets `RAILS_ENV=production`. Rails' own log lines are kept at warnings and errors, in the same format as the rest.

Metrics are pulled, not pushed: scrape `/metrics`. You get `http_requests_total` and `http_request_duration_seconds` by method, route template and status, `arith_operations_total` by operation and outcome (`ok`, `bad_input`, `division_by_zero`, `overflow`), and `arith_build_info`.

Two shapes that work:

```sh
# Through a collector (Alloy, the OpenTelemetry Collector) that fans out to Tempo and Loki.
OTEL_TRACES_EXPORTER=otlp OTEL_LOGS_EXPORTER=console,otlp \
OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.monitoring.svc:4318 make run

# Straight to the stores. Tempo takes OTLP on 4318. Loki takes OTLP logs on /otlp.
OTEL_TRACES_EXPORTER=otlp OTEL_LOGS_EXPORTER=otlp \
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://tempo:4318/v1/traces \
OTEL_EXPORTER_OTLP_LOGS_ENDPOINT=http://loki:3100/otlp/v1/logs make run
```

A request that arrives with a W3C `traceparent` header joins that trace, so a span from a gateway in front continues into the service. Each access-log line carries the trace id, as a field on stdout and in the record itself over OTLP.

If an agent already tails pod stdout into Loki, pick one of `console` and `otlp` for logs, or every line is stored twice.

## Deploy

You need `kubectl` pointed at a cluster, and `helm` 3.8 or newer for the Helm path. The default install is a Deployment and a ClusterIP Service in namespace `arith`. Helm and Kustomize produce the same objects.

### 1. Deploy the public image

```sh
git clone https://github.com/giovannirco/arith-ruby && cd arith-ruby
helm install arith deploy/helm/arith-ruby --namespace arith --create-namespace --wait
```

The same with Kustomize, no Helm needed:

```sh
kubectl apply -k deploy/kustomize/base
kubectl -n arith rollout status deployment/arith
```

### 2. Request it from inside the cluster

```sh
kubectl -n arith run client --rm -i --restart=Never --image=curlimages/curl:8.22.0 \
  --command -- sh -c "sleep 2; curl -s 'http://arith:8000/api/sub?term_one=4&term_two=1'"
```

Prints `{"result":3}`. The pause lets kubectl attach before curl exits; without it a pod this quick often prints nothing. `helm test arith -n arith` runs the same check as a Helm test. For the page:

```sh
kubectl -n arith port-forward svc/arith 8000:8000
```

and open <http://localhost:8000>.

### 3. Change the API and redeploy

Any edit works. The one used for the dry run makes `sum` saturate at the 64-bit limits instead of refusing. In `app/models/calc.rb`:

```diff
-  def sum(a, b) = fit(a + b)
+  def sum(a, b) = (a + b).clamp(MIN, MAX)
```

`make test` now fails on the overflow expectations for `sum`. That is the suite doing its job. Three places disagree with the new behaviour:

- two rows in the table in `test/models/calc_test.rb`: change `[ :sum, MAX, 1, OVERFLOW ]` to `[ :sum, MAX, 1, MAX ]` and `[ :sum, MIN, -1, OVERFLOW ]` to `[ :sum, MIN, -1, MIN ]`;
- one case in `test/integration/api_test.rb`, `/api/sum?term_one=9223372036854775807&term_two=1` in `errors are 400 with a reason`: move it into `the worked example` as `assert_json 200, '{"result":9223372036854775807}', "/api/sum?term_one=9223372036854775807&term_two=1"`.

Run `make test` again until it passes, then build and roll out:

```sh
make test
make image TAG=2
```

Put the image where the cluster can pull it. For kind:

```sh
kind load docker-image ghcr.io/giovannirco/arith-ruby:2 --name kind
```

For minikube, `minikube image load ghcr.io/giovannirco/arith-ruby:2`. For a real cluster, push to a registry it trusts and add `--set image.repository=registry.example.com/arith` to the next command.

```sh
helm upgrade arith deploy/helm/arith-ruby --namespace arith --set image.tag=2 --wait
```

With Kustomize: `kubectl -n arith set image deployment/arith arith=ghcr.io/giovannirco/arith-ruby:2 && kubectl -n arith rollout status deployment/arith`, and write the new tag into `deploy/kustomize/base/kustomization.yaml` so the next apply keeps it.

Then ask again:

```sh
kubectl -n arith run client --rm -i --restart=Never --image=curlimages/curl:8.22.0 \
  --command -- sh -c "sleep 2; curl -s 'http://arith:8000/api/sum?term_one=9223372036854775807&term_two=1'"
```

Prints `{"result":9223372036854775807}` where tag 1 answered `400`.

### 4. Remove

```sh
helm uninstall arith --namespace arith
kubectl delete namespace arith
```

With Kustomize, `kubectl delete -k deploy/kustomize/base` removes the namespace too.

## Versions

Two numbers, and they move separately.

- The **image tag** is a plain integer: `ghcr.io/giovannirco/arith-ruby:1`, `:2`. `--set image.tag=2` or `kubectl set image` rolls one out. `make image TAG=2` builds one locally.
- The **chart version** is semver, in `deploy/helm/arith-ruby/Chart.yaml`. It goes up whenever a template or a default changes, and the chart's `appVersion` is the image tag it installs by default.

A release is a commit that bumps the chart version, then a numeric git tag: `git tag 2 && git push origin 2`. CI publishes the image as `:2` and `:latest`, and the chart at its new version with `appVersion` set to `2`. If that chart version is already on GHCR the chart job fails instead of overwriting it. `oras repo tags ghcr.io/giovannirco/charts/arith-ruby` lists what is published, and

```sh
helm install arith oci://ghcr.io/giovannirco/charts/arith-ruby --version <chart version> --namespace arith --create-namespace
```

installs a particular one. The chart in this repository keeps `appVersion: "1"`, so section 3 above always shows a rollout from 1 to 2. Follow the walkthrough with that chart, not a published one: a published chart defaults to the newest image, and `--set image.tag=2` may then change nothing.

## Optional pieces

Each one is a Helm toggle and a Kustomize component, off by default, because each needs something a cluster may not have.

| Piece | Helm value | Kustomize component | Needs |
|---|---|---|---|
| Ingress | `ingress.enabled` | `components/ingress` | an ingress controller |
| HTTPRoute | `httpRoute.enabled` | `components/httproute` | Gateway API and a Gateway to attach to |
| NetworkPolicy | `networkPolicy.enabled` | `components/networkpolicy` | a CNI that enforces policy |
| CiliumNetworkPolicy | `ciliumNetworkPolicy.enabled` | `components/cilium-networkpolicy` | Cilium |
| ServiceMonitor | `serviceMonitor.enabled` | `components/servicemonitor` | the Prometheus Operator CRDs |
| OTLP export | `env.OTEL_*` | `components/otlp` | a collector, Tempo or Loki to send to |

The two network policies default-deny and then allow: ingress on 8000 from pods in the cluster (or from the namespaces you list, such as your gateway's), probes from the nodes, egress to DNS and to whatever you name as a destination (your OTLP collector). `deploy/helm/arith-ruby/values.yaml` documents every value. `deploy/kustomize/overlays/example` composes every component with placeholder names. `deploy/examples/arith.giovanni.dev.br.yaml` is a full set that actually runs.

## Layout

```
app/models/calc.rb            sum, sub, mul, div on 64-bit integers
app/models/terms.rb           reading term_one and term_two from the query
app/controllers/              the JSON handlers, the page, /healthz, /metrics, errors
config/routes.rb              every route, and the 405 for each path
config/puma.rb                listen, drain on SIGTERM
config/application.rb         Rails with only Action Pack, the JSON error app
lib/arith/observe.rb          one span, the request metrics and one log line per request
lib/arith/metrics.rb          the Prometheus registry
lib/arith/telemetry.rb        where logs and traces go
lib/arith/log.rb              the log line format
lib/arith/config.rb           the environment variables
web/                          index.html, style.css, app.js
test/                         the table of cases, the HTTP contract, the process
Dockerfile                    ruby:alpine build and runtime, uid 65532
deploy/helm/arith-ruby        the chart
deploy/kustomize              base, components, an example overlay
Makefile                      test, cover, lint, run, image, push, deploy, upgrade, remove
```

To add or change an operation: edit the method in `app/models/calc.rb`, add its rows to the table in `test/models/calc_test.rb`, give it an action in `app/controllers/operations_controller.rb`, route it in `config/routes.rb` (the GET route and the path in the 405 list), and give the page a button in `web/index.html`. The error strings live in `app/models/calc.rb` and `app/models/terms.rb`, next to the tests that pin them.

## License

[MIT](LICENSE)

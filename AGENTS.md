# arith-ruby

Read [README.md](README.md) first. That file is the contract. If a command in it does not match the tree, fix the tree or the README in the same change. A documented command that does not run is a bug.

This repository is the open-source arithmetic service the README describes. Code, docs, commits, UI copy and issues stay on that subject.

## Shape

One Ruby process: Rails in API-only mode, loading only Action Pack, served by Puma. No database, no mail, no jobs, no views. Port 8000 is fixed. The page and the API ship in the same image.

```
app/models/calc.rb         the four operations on 64-bit integers
app/models/terms.rb        term_one and term_two from the raw query string
app/controllers/           operations, the page, /healthz, /metrics, 404 and 405
config/routes.rb           every route, and the 405 for each path
config/application.rb      Rails with only Action Pack, the JSON exceptions app
config/puma.rb             listen, drain on SIGTERM, refuse a bad setting
config/initializers/       telemetry and the metrics registry, once
lib/arith/observe.rb       per-request span, metrics and access log
lib/arith/metrics.rb       Prometheus registry behind /metrics
lib/arith/telemetry.rb     OTLP exporters for logs and traces
lib/arith/log.rb           the one log line format, JSON or text
lib/arith/config.rb        environment variables, parsed once
web/                       index.html, style.css, app.js; no build step
test/                      the table of cases, the HTTP contract, the Puma process
Dockerfile                 ruby:alpine build and runtime stages, uid 65532
deploy/helm/arith-ruby     chart: Deployment, Service, optional Ingress, HTTPRoute,
                           NetworkPolicy, CiliumNetworkPolicy, ServiceMonitor, a helm test
deploy/kustomize           base (namespace, deployment, service), one component per
                           optional piece, an example overlay
.github/workflows          test, lint, coverage, multi-arch image and chart to ghcr
Makefile                   test, cover, lint, run, image, push, deploy, upgrade, remove
```

Operations live in `app/models/calc.rb`. Adding or changing one is a method there and its rows in `test/models/calc_test.rb`, an action in `app/controllers/operations_controller.rb`, a route in `config/routes.rb`, a button in `web/index.html`. The README's layout section points at these files. Keep that true.

`lib/` is plain Ruby, required by `config/application.rb` and by `config/puma.rb` before Rails boots; only `app/` is autoloaded.

## API

Match the table in the README, including the error strings. Signed 64-bit integers only: Ruby's integers do not overflow, so every term and every result is checked against the range. Division truncates toward zero, which Ruby's `/` does not. Division by zero, a missing or non-integer term, and a result that does not fit are all `400` with `{"error":"..."}`. Unknown path `404`, wrong method `405`, both JSON. Tests pin every string; change the test and the string together.

`/healthz` is the only health URL. Liveness and readiness both use it.

## Observability

Metrics are pulled from `/metrics` and always on. Traces and logs leave over OTLP only when the standard `OTEL_*` variables ask for it. Defaults are stdout logs and no traces. Do not invent `ARITH_*` names for things OpenTelemetry already names. Labels on metrics stay bounded: route template, not path; outcome enum, not error text.

The OpenTelemetry providers are built by hand in `lib/arith/telemetry.rb`. `OpenTelemetry::SDK.configure` turns trace export on when `OTEL_TRACES_EXPORTER` is unset, which this service must not do.

## Page

One screen. Two inputs, four operations, the result, the error text the API returned, and the request line that produced them. It calls the same endpoints the tests do and computes nothing itself.

Keep it quiet: system fonts, one accent, generous space, a result readable from across a desk, light and dark. No canvas, no chart, no dashboard, no traffic generator, no UI framework, no build step. It has to work at phone width and look finished at laptop width.

## Cluster

Both Helm and Kustomize must produce the same default objects: a Deployment with both probes on `/healthz`, non-root, read-only root filesystem, small requests, one replica, `maxUnavailable: 0`; a ClusterIP Service on 8000. The default install must succeed on a vanilla cluster with no ingress controller, no particular CNI, no operator.

Everything else is a toggle that is off by default: Ingress, HTTPRoute, NetworkPolicy, CiliumNetworkPolicy, ServiceMonitor, OTLP export. A toggle in `values.yaml` has a matching component under `deploy/kustomize/components`. When you add a knob to one, add it to the other.

The README has four pasteable sections, and they are the acceptance test: deploy the public image; request the worked example from a pod in the namespace; change `sum`, build tag `2`, roll it out, request again; delete the namespace. Run them on a clean kind cluster before calling a change done.

Image: `ghcr.io/giovannirco/arith-ruby`. Tags are plain integers (`1`, `2`), so a rollout is `--set image.tag=2` or `kubectl set image` with one variable. CI publishes a multi-arch image and the chart from a git tag. The Makefile builds the operator's local tag. The process writes nothing to disk, so the root filesystem stays read-only without an `emptyDir`.

## Tests

`make test` is the suite, `make cover` the coverage report. Cover the worked example, truncation in both signs, division by zero, a missing term, a non-integer, a term outside 64 bits, overflow in every operation, the error bodies, the page and its assets, the metrics text, graceful shutdown and the exporter wiring. Keep `bin/rubocop` clean. Do not add a coverage threshold whose only job is to print a number.

## Versions

Pin what you depend on and look the version up before pinning it: base images by tag and digest, the curl image for tests, gem versions in `Gemfile.lock`. Never write a version from memory.

## Out of scope

A second service. A database. Authentication. A service mesh. An Ingress or a LoadBalancer in the default install. A UI framework or a frontend build step. Pushing metrics anywhere.

## Done

- `make lint`, `make test` and `make cover` pass.
- `make run`, then every row of the README's API table returns the documented body, and `/` renders.
- `make image` produces an image that serves on 8000 as uid 65532 with a read-only root.
- `helm lint`, `helm template` with every toggle on, and `kubectl kustomize deploy/kustomize/overlays/example` all render and dry-run apply.
- On a clean kind cluster, following only the README: deploy, request from a pod, change `sum`, redeploy, request again, delete; namespace gone.

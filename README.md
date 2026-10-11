# arith-ruby

Integer arithmetic over HTTP: `GET /api/{sum,sub,mul,div}?term_one=<int>&term_two=<int>` answers `{"result": <int>}`. One Ruby process (Rails in API-only mode on Puma) listening on port 8000, with a health check at `/healthz`, Prometheus metrics at `/metrics` and a small page at `/`.

The default install is a Deployment and a **ClusterIP** Service: reachable only from inside the cluster, and it needs nothing else from the cluster (no ingress controller, no particular CNI, no operator). Exposing it publicly is an optional extra (see [Optional pieces](#optional-pieces)).

The same contract is implemented three times; this is the Ruby one. The others are <https://github.com/giovannirco/arith-ts> (TypeScript, the one running at <https://arith-ts.giovanni.dev.br>) and <https://github.com/giovannirco/arith-rust> (Rust).

## Prerequisites

- A Kubernetes cluster and `kubectl` pointed at it.
- `helm` 3.8 or newer.
- For step 3 only: `git`, `make`, Docker, and Ruby 4.0 with Bundler to run the tests. To get the image into the cluster you also need kind or minikube, or a registry the cluster can pull from.

## The API

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

Terms and results are signed 64-bit integers. Division truncates toward zero (`-7/2 = -3`). Bad input, division by zero and a result that does not fit are `400` with a JSON reason; an unknown path is `404` and another method `405`, both JSON. In a query string `+` means a space, so send `%2B2` (or just `2`) for a positive sign.

## 1. Deploy

```sh
git clone https://github.com/giovannirco/arith-ruby && cd arith-ruby
helm install arith deploy/helm/arith-ruby --namespace arith --create-namespace --wait
```

This installs image `ghcr.io/giovannirco/arith-ruby:1.1.0`, the release the chart belongs to. Without Helm: `kubectl apply -k deploy/kustomize/base && kubectl -n arith rollout status deployment/arith`.

## 2. Verify

From a pod inside the cluster:

```sh
kubectl -n arith run client --rm -i --restart=Never --image=curlimages/curl:8.22.0 \
  --command -- sh -c "sleep 2; curl -s 'http://arith:8000/api/sub?term_one=4&term_two=1'"
```

Prints `{"result":3}`. (The pause lets kubectl attach before curl exits.) `helm test arith -n arith` runs the same check. To see the page: `kubectl -n arith port-forward svc/arith 8000:8000` and open <http://localhost:8000>.

## 3. Change the API and redeploy

The example makes `sum` saturate at the 64-bit limits instead of refusing. In `app/models/calc.rb`:

```diff
-  def sum(a, b) = fit(a + b)
+  def sum(a, b) = (a + b).clamp(MIN, MAX)
```

The tests pin the old behaviour, so update them too:

- two rows in the table in `test/models/calc_test.rb`: change `[ :sum, MAX, 1, OVERFLOW ]` to `[ :sum, MAX, 1, MAX ]` and `[ :sum, MIN, -1, OVERFLOW ]` to `[ :sum, MIN, -1, MIN ]`;
- one case in `test/integration/api_test.rb`, `/api/sum?term_one=9223372036854775807&term_two=1` in `errors are 400 with a reason`: move it into `the worked example` as `assert_json 200, '{"result":9223372036854775807}', "/api/sum?term_one=9223372036854775807&term_two=1"`.

Then test, build under the local tag `dev` (no release uses it, so the cluster cannot pull a different image by that name), load it into the cluster and roll it out:

```sh
bundle install && make test
make image TAG=dev
kind load docker-image ghcr.io/giovannirco/arith-ruby:dev            # kind (add --name <cluster> if not "kind")
# minikube image load ghcr.io/giovannirco/arith-ruby:dev             # or minikube
helm upgrade arith deploy/helm/arith-ruby --namespace arith --set image.tag=dev --wait
```

On a cluster that pulls from a registry, build and push to yours instead: `make image push IMAGE=registry.example.com/arith-ruby TAG=dev` (add `PLATFORM=linux/amd64` when your machine and the cluster's nodes differ), then add `--set image.repository=registry.example.com/arith-ruby` to the `helm upgrade`.

Ask again:

```sh
kubectl -n arith run client --rm -i --restart=Never --image=curlimages/curl:8.22.0 \
  --command -- sh -c "sleep 2; curl -s 'http://arith:8000/api/sum?term_one=9223372036854775807&term_two=1'"
```

Prints `{"result":9223372036854775807}` where the release answered `400`.

## 4. Remove

```sh
helm uninstall arith --namespace arith
kubectl delete namespace arith
```

With Kustomize: `kubectl delete -k deploy/kustomize/base`.

## Tests and coverage

```sh
bundle install
make test     # Minitest: the table of cases, the HTTP contract, metrics, spans, the real Puma process
make cover    # the same with SimpleCov line coverage, report in coverage/index.html
make lint     # RuboCop (Rails omakase)
make run      # serve on :8000 with readable logs
```

CI runs lint, tests with coverage, the chart and Kustomize renders, and installs this commit's image with the chart on a kind cluster and runs `helm test`.

## Configuration

Environment variables; the chart sets them through `env` in `values.yaml`.

| Variable | Default | Meaning |
|---|---|---|
| `ARITH_ADDR` | `0.0.0.0:8000` | Listen address |
| `ARITH_LOG_LEVEL` | `info` | `debug`, `info`, `warn` or `error` |
| `ARITH_LOG_FORMAT` | `json` | `json` or `text` |
| `ARITH_SHUTDOWN_TIMEOUT` | `10` | Seconds to finish in-flight requests after SIGTERM |
| `OTEL_TRACES_EXPORTER` | `none` | `otlp` sends one span per request |
| `OTEL_LOGS_EXPORTER` | `console` | `console`, `otlp`, `console,otlp` or `none` |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | `http/protobuf` | The only transport Ruby's exporters have |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | `http://localhost:4318` | The collector; the other standard `OTEL_*` variables apply too |

A value the program cannot use stops it at start with a message naming the variable. The image sets `RAILS_ENV=production`; `SECRET_KEY_BASE` is optional, since nothing here is signed or encrypted.

## Optional pieces

Off by default; each is a Helm value and a matching Kustomize component, because each needs something a cluster may not have.

| Piece | Helm value | Needs |
|---|---|---|
| Ingress | `ingress.enabled` | an ingress controller |
| HTTPRoute (public access) | `httpRoute.enabled` | Gateway API and a Gateway |
| NetworkPolicy | `networkPolicy.enabled` | a CNI that enforces policy |
| CiliumNetworkPolicy | `ciliumNetworkPolicy.enabled` | Cilium |
| ServiceMonitor | `serviceMonitor.enabled` | the Prometheus Operator CRDs |
| OTLP export | `env.OTEL_*` | a collector |

`deploy/kustomize/overlays/example` composes every component with placeholder names. None of it is needed for steps 1 to 4. The TypeScript implementation's `deploy/examples` holds a full set that runs on a real cluster.

## Versions and releases

One version per release, semver, written in `lib/arith/version.rb` and repeated in `Chart.yaml` (`version` and `appVersion`), the Kustomize base and this README; CI fails if any of them disagree. The current release is `v1.1.0`: image `ghcr.io/giovannirco/arith-ruby:1.1.0` and chart `oci://ghcr.io/giovannirco/charts/arith-ruby` version `1.1.0`, which installs that image by default. Commits on master (and pull requests from this repository) also get an image `:sha-<commit>`. CI never publishes `latest` or a bare-integer tag, and never republishes a version.

To release: bump the version in all of those places in one commit, merge it, then `git tag v$(make version) && git push origin v$(make version)`.

```sh
helm install arith oci://ghcr.io/giovannirco/charts/arith-ruby --version 1.1.0 --namespace arith --create-namespace
```

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
Makefile                      version, test, cover, lint, run, image, push, deploy, upgrade, remove
```

To add or change an operation: edit the method in `app/models/calc.rb`, add its rows to the table in `test/models/calc_test.rb`, give it an action in `app/controllers/operations_controller.rb`, route it in `config/routes.rb` (the GET route and the path in the 405 list), and give the page a button in `web/index.html`. The error strings live in `app/models/calc.rb` and `app/models/terms.rb`, next to the tests that pin them.

## License

[MIT](LICENSE)

# arith

arith does integer arithmetic over HTTP: four endpoints, a page that calls them, and Prometheus metrics. One Ruby process, Rails in API-only mode on Puma, on port 8000, deployed to Kubernetes with Helm or Kustomize.

**Status:** this file and `AGENTS.md` describe the service before it exists. The run, configuration and deploy sections arrive with the code that makes them true.

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

## License

[MIT](LICENSE)

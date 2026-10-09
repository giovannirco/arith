# Contributing

[README.md](README.md) is the contract: the API table, the error strings and the deploy steps. A change that breaks a documented command fixes the command or the README in the same commit.

- You need Ruby 4.0 and Bundler. `.ruby-version` names the exact Ruby CI and the image use; run `bundle install` once.
- `make test` and `make lint` pass before you push. `make lint` is RuboCop with the Rails omakase style, as CI runs it.
- Gems move by hand: `bundle update <gem>`, then `make test`, with the `Gemfile.lock` change in the same commit.
- One concern per commit, with a [conventional](https://www.conventionalcommits.org) subject: `feat:`, `fix(helm):`, `docs:`, `ci:`.
- Image tags stay plain integers: `1`, `2`. Do not add `v` prefixes or semver to image tags.
- The chart version in `deploy/helm/arith-ruby/Chart.yaml` is semver. Bump it in the commit that changes a template or a default; CI will not publish a version twice.
- A Helm value and a Kustomize component come together: add a toggle to one, add it to the other.

Open an issue or a pull request in plain words: what you ran, what you expected, what happened.

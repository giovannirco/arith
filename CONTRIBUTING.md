# Contributing

[README.md](README.md) is the contract: the API table, the error strings and the deploy steps. A change that breaks a documented command fixes the command or the README in the same commit.

- You need Ruby 4.0 and Bundler. `.ruby-version` names the exact Ruby CI and the image use; run `bundle install` once.
- `make test` and `make lint` pass before you push. `make lint` is RuboCop with the Rails omakase style, as CI runs it.
- Gems move by hand: `bundle update <gem>`, then `make test`, with the `Gemfile.lock` change in the same commit.
- One concern per commit, with a [conventional](https://www.conventionalcommits.org) subject: `feat:`, `fix(helm):`, `docs:`, `ci:`.
- One version per release, semver: `lib/arith/version.rb`, `Chart.yaml` (`version`, `appVersion`, the `artifacthub.io/images` tag), `deploy/kustomize/base/kustomization.yaml` and the docs carry the same one, and CI checks it. A release is a commit that bumps all of them, then a tag `v<version>`; CI never publishes a version twice.
- Image tags are that version (`1.1.0`) or `sha-<commit>`. Never a bare integer, never `latest`. Build locally with `make image TAG=dev`.
- A Helm value and a Kustomize component come together: add a toggle to one, add it to the other.

Open an issue or a pull request in plain words: what you ran, what you expected, what happened.

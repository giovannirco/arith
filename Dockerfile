# syntax=docker/dockerfile:1

# Stage 1: install the gems, compiling Puma's C extension.
FROM ruby:4.0.7-alpine3.24@sha256:1ca7cb33e970630d571e0da6140e0bc925faec8f1f8f51f9f2cdf5e5f5eed7c9 AS build
RUN apk add --no-cache build-base
WORKDIR /app
ENV BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/usr/local/bundle
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install --jobs 4 && \
    rm -rf /usr/local/bundle/cache /usr/local/bundle/ruby/*/cache
COPY config.ru Rakefile ./
COPY app ./app
COPY bin ./bin
COPY config ./config
COPY lib ./lib
COPY web ./web

# Stage 2: Ruby, the installed gems and the app, run as a non-root user.
# Nothing is written at runtime, so the root filesystem can be read-only.
FROM ruby:4.0.7-alpine3.24@sha256:1ca7cb33e970630d571e0da6140e0bc925faec8f1f8f51f9f2cdf5e5f5eed7c9
# Ruby 4.0.7 ships json 2.18.0 as a default gem, which has CVE-2026-33210
# (critical) and CVE-2026-54696. The app never loads it: Gemfile.lock pins
# json 3.0.2 and the bundle provides it. The default copy is removed so the
# vulnerable code is not in the image, and the build checks that json still
# loads from the bundle. zlib comes up to 1.3.2-r1 (CVE-2026-85091). Both can
# go once the base image carries the fixes.
RUN apk add --no-cache --upgrade 'zlib>=1.3.2-r1' && \
    rm -rf /usr/local/lib/ruby/4.0.0/json /usr/local/lib/ruby/4.0.0/json.rb \
           /usr/local/lib/ruby/4.0.0/*-linux-musl/json \
           /usr/local/lib/ruby/gems/4.0.0/gems/json-2.18.0 \
           /usr/local/lib/ruby/gems/4.0.0/specifications/default/json-2.18.0.gemspec
LABEL org.opencontainers.image.source="https://github.com/giovannirco/arith-ruby" \
      org.opencontainers.image.description="Integer arithmetic over HTTP: four endpoints, a page, metrics, traces and logs." \
      org.opencontainers.image.licenses="MIT"
# BUNDLE_USER_HOME stops Bundler looking for a writable home directory.
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_USER_HOME=/usr/local/bundle/home
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
RUN ruby -rbundler/setup -rjson -e \
      'abort "json #{JSON::VERSION} is not the bundled one" if Gem::Version.new(JSON::VERSION) < Gem::Version.new("2.19.9")'
EXPOSE 8000
# By number, so `runAsNonRoot: true` can verify it. The same uid distroless
# images call nonroot.
USER 65532:65532
ENTRYPOINT ["bin/puma", "-C", "config/puma.rb"]

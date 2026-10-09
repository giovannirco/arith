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
LABEL org.opencontainers.image.source="https://github.com/giovannirco/arith" \
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
EXPOSE 8000
# By number, so `runAsNonRoot: true` can verify it. The same uid distroless
# images call nonroot.
USER 65532:65532
ENTRYPOINT ["bin/puma", "-C", "config/puma.rb"]

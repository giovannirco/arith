# Variables you may want to override on the command line:
#   make image TAG=2
#   make deploy TAG=2 NAMESPACE=arith
IMAGE     ?= ghcr.io/giovannirco/arith-ruby
TAG       ?= 1
NAMESPACE ?= arith
RELEASE   ?= arith
CHART     ?= deploy/helm/arith-ruby

.PHONY: help test cover lint run image push deploy upgrade remove kustomize-deploy kustomize-remove

help: ## This list
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

test: ## Unit and HTTP tests
	bin/rails test

cover: ## Tests with a line coverage report (SimpleCov)
	COVERAGE=1 bin/rails test
	@echo "HTML report: coverage/index.html"

lint: ## RuboCop, as CI runs it
	bin/rubocop

run: ## Serve on :8000 with readable logs
	ARITH_LOG_FORMAT=text bin/puma -C config/puma.rb

image: ## Build $(IMAGE):$(TAG) for this machine's architecture
	docker build -t $(IMAGE):$(TAG) .

push: ## Push $(IMAGE):$(TAG)
	docker push $(IMAGE):$(TAG)

deploy: ## Install or upgrade the Helm release with image tag $(TAG)
	helm upgrade --install $(RELEASE) $(CHART) \
	  --namespace $(NAMESPACE) --create-namespace \
	  --set image.tag=$(TAG) --wait

upgrade: deploy ## Same as deploy; reads better after a change

remove: ## Uninstall the release and delete the namespace
	helm uninstall $(RELEASE) --namespace $(NAMESPACE) --ignore-not-found
	kubectl delete namespace $(NAMESPACE) --ignore-not-found

kustomize-deploy: ## The same deployment through kubectl apply -k
	kubectl apply -k deploy/kustomize/base
	kubectl -n $(NAMESPACE) rollout status deployment/arith

kustomize-remove: ## Delete what kustomize-deploy created, namespace included
	kubectl delete -k deploy/kustomize/base --ignore-not-found

# ===== Core settings (Go + Frontend) =====
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

# ----- Meta -----
DATE     := $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_SHA  := $(shell git rev-parse --short HEAD 2>/dev/null || echo "nogit")
VERSION  ?= $(shell git describe --tags --always --dirty 2>/dev/null || echo 0.0.0-dev)

# ----- Paths -----
BIN_DIR   := bin
ARTIFACTS := artifacts

# ----- Toolchains -----
GO      := go
DOCKER  := docker
COMPOSE := docker compose
PKG_MGR := $(shell command -v pnpm >/dev/null 2>&1 && echo pnpm || (command -v yarn >/dev/null 2>&1 && echo yarn || echo npm))
# so go install-ed tools are available
export PATH := $(shell go env GOPATH)/bin:$(PATH)

# ----- Reproducible build defaults -----
export GOWORK := off
GO_BUILD_FLAGS ?= -trimpath
# GO_BUILD_FLAGS += -buildvcs=false   # enable if you want reproducible builds without VCS metadata
GOFLAGS ?= -mod=readonly
CGO_ENABLED ?= 0

# ----- Services & images -----
SERVICES ?= auth user file gateway verification worker-ttl
APP_NAME ?= cloudeck
REGISTRY ?= ghcr.io/your-org
IMAGE    ?= $(REGISTRY)/$(APP_NAME)

# ----- Go ldflags -----
GO_LDFLAGS := -s -w \
	-X 'main.version=$(VERSION)' \
	-X 'main.commit=$(GIT_SHA)' \
	-X 'main.date=$(DATE)'

# ===== Helpers =====
.PHONY: help vars clean distclean verify
help: ## Show available commands
	@awk 'BEGIN {FS=":.*##"; printf "\nUsage: make \033[36m<target>\033[0m\n\nTargets:\n"} /^[a-zA-Z0-9_\/.\-]+:.*##/ { printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

vars: ## Print important variables
	@echo VERSION=$(VERSION); echo GIT_SHA=$(GIT_SHA); echo IMAGE=$(IMAGE); echo PKG_MGR=$(PKG_MGR); echo GOWORK=$(GOWORK)

$(BIN_DIR) $(ARTIFACTS): ## Create helper directories
	mkdir -p $@

clean: ## Remove build/test artifacts
	rm -rf $(BIN_DIR) $(ARTIFACTS) .stamps

distclean: clean ## Full cleanup (including deps/gen)
	rm -rf node_modules apps/*/node_modules gen

verify: fmt lint test build ## Quick check before push

# ===== Bootstrap (Go tools + Frontend) =====
STAMPS := .stamps
$(STAMPS): ; mkdir -p $@

.PHONY: bootstrap bootstrap.go bootstrap.node
bootstrap: bootstrap.go bootstrap.node ## Install Go tools and frontend deps

bootstrap.go: $(STAMPS)/go.ok
$(STAMPS)/go.ok: | $(STAMPS)
	$(GO) install gotest.tools/gotestsum@latest
	$(GO) install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	touch $@

bootstrap.node: | $(STAMPS) ## Install frontend deps if apps/web/package.json exists
	@if [ -f apps/web/package.json ]; then $(MAKE) $(STAMPS)/node.ok; else echo "skip node (no apps/web/package.json)"; fi
$(STAMPS)/node.ok: apps/web/package.json | $(STAMPS)
	cd apps/web && $(PKG_MGR) install
	touch $@

# ===== Optional: generate (IDL/mocks/etc.) =====
.PHONY: generate
generate: ## Run code generation (if scripts exist) + check for uncommitted changes
	@if [ -x scripts/gen-openapi.sh ]; then scripts/gen-openapi.sh; else echo "skip openapi (no scripts/gen-openapi.sh)"; fi
	@if [ -x scripts/gen-proto.sh ];   then scripts/gen-proto.sh;   else echo "skip proto (no scripts/gen-proto.sh)"; fi
	@if [ -x scripts/gen-mocks.sh ];   then scripts/gen-mocks.sh;   else echo "skip mocks (no scripts/gen-mocks.sh)"; fi
	@# Fail if there are modified or untracked files
	@if command -v git >/dev/null 2>&1; then \
	  dirty=0; \
	  git diff --quiet --ignore-submodules -- || dirty=1; \
	  if [ -n "$$(git ls-files --others --exclude-standard | head -n1)" ]; then dirty=1; fi; \
	  if [ "$$dirty" -ne 0 ]; then \
	    echo "Generated files changed or untracked — commit them:"; \
	    git --no-pager status --porcelain; \
	    exit 1; \
	  fi; \
	fi

# ===== Formatting (Go + TS) =====
.PHONY: fmt
fmt: ## Format Go/TS
	$(GO) fmt ./...
	[ -f apps/web/package.json ] && (cd apps/web && $(PKG_MGR) run fmt) || true

# ===== Linters (Go + TS + misc) =====
.PHONY: lint
lint: ## golangci-lint, ESLint, shellcheck, yamllint, hadolint (soft skips)
	@if command -v golangci-lint >/dev/null 2>&1; then \
	  if [ -f .golangci.yml ] || [ -f .golangci.yaml ] || [ -f .golangci.toml ]; then \
	    golangci-lint run; \
	  else \
	    echo "no .golangci.yml — running with defaults (add config to pin rules)"; \
	    golangci-lint run || true; \
	  fi; \
	else echo "golangci-lint not installed, skipping"; fi
	[ -f apps/web/package.json ] && (cd apps/web && $(PKG_MGR) run lint) || true
	(command -v shellcheck >/dev/null && shellcheck -x $$(git ls-files "*.sh")) || true
	(command -v yamllint  >/dev/null && yamllint -s .) || true
	(command -v hadolint  >/dev/null && hadolint $$(git ls-files "*Dockerfile*")) || true

# ===== Tests & Coverage =====
.PHONY: test test.unit test.int test.services test.ts coverage
TEST_FLAGS     ?= -race -covermode=atomic -coverprofile=$(ARTIFACTS)/coverage.out
TEST_INT_TAGS  ?= -tags=integration
PKG            ?= ./...
RUN            ?=

test: test.unit test.ts ## Run Go unit tests + frontend tests (if any)

test.unit: | $(ARTIFACTS) ## Run Go unit tests (PKG/RUN), fallback if gotestsum is missing
	@if command -v gotestsum >/dev/null 2>&1; then \
	  gotestsum --format standard-verbose --junitfile $(ARTIFACTS)/junit.xml \
	    -- $(TEST_FLAGS) -run '$(RUN)' $(PKG); \
	else \
	  echo "gotestsum not found → fallback to 'go test' (no JUnit)"; \
	  $(GO) test $(TEST_FLAGS) -run '$(RUN)' $(PKG); \
	fi

test.int: dev-up ## Run integration tests (requires local env)
	@$(GO) test $(TEST_INT_TAGS) -run '$(RUN)' $(PKG)

test.services: | $(ARTIFACTS) ## Run unit tests per service (separate reports)
	@for s in $(SERVICES); do \
	  if [ -d services/$$s ]; then \
	    echo ">> $$s unit tests"; \
	    if command -v gotestsum >/dev/null 2>&1; then \
	      (cd services/$$s && gotestsum --format standard-verbose \
	        --junitfile ../../$(ARTIFACTS)/junit-$$s.xml -- -race ./...) || exit 1; \
	    else \
	      (cd services/$$s && go test -race ./...) || exit 1; \
	    fi; \
	  else echo "skip $$s (no services/$$s)"; fi; \
	done

test.ts: ## Run frontend tests (if any)
	@if [ -f apps/web/package.json ]; then cd apps/web && $(PKG_MGR) test || true; else echo "skip frontend tests"; fi

coverage: test.unit ## Show coverage summary
	@go tool cover -func=$(ARTIFACTS)/coverage.out | tail -n 1 || echo "no coverage profile yet"

# ===== Observability lint (Prometheus/Grafana) =====
.PHONY: prom.lint grafana.lint test.obs
prom.lint: ## Validate Prometheus rules/config (promtool), skip if not installed
	@if command -v promtool >/dev/null 2>&1; then \
	  if [ -d observability/prometheus ]; then \
	    find observability/prometheus -type f \( -name '*.yml' -o -name '*.yaml' \) | while read -r f; do \
	      [ -n "$$f" ] && promtool check rules "$$f" || true; \
	    done; \
	    [ -f observability/prometheus/prometheus.yml ] && promtool check config observability/prometheus/prometheus.yml || true; \
	  else echo "skip prom (no observability/prometheus)"; fi; \
	else echo "promtool not installed, skipping"; fi

grafana.lint: ## Validate Grafana dashboards JSON (jq), skip if not installed
	@if [ -d observability/grafana/dashboards ]; then \
	  if command -v jq >/dev/null 2>&1; then \
	    for f in observability/grafana/dashboards/*.json; do [ -e "$$f" ] || continue; jq -e . "$$f" >/dev/null || exit 1; done; \
	  else echo "skip grafana (jq not installed)"; fi; \
	else echo "skip grafana (no observability/grafana/dashboards)"; fi

test.obs: prom.lint grafana.lint ## Run observability config checks

# ===== Build (Go services + Web) =====
.PHONY: build build/services build/% build/web
build: build/services build/web ## Build all services and frontend

build/services: $(SERVICES:%=build/%) ## Build all services (bin/<svc>)

.PHONY: build/%
build/%: | $(BIN_DIR) ## Build specific service: build/<svc> → bin/<svc>
	@if [ -d services/$* ]; then \
	  if [ -d services/$*/cmd/$* ]; then \
	    echo ">> building $*"; \
	    CGO_ENABLED=$(CGO_ENABLED) $(GO) build $(GO_BUILD_FLAGS) -ldflags "$(GO_LDFLAGS)" \
	      -o $(BIN_DIR)/$* ./services/$*/cmd/$*; \
	  else echo "skip $*: services/$*/cmd/$* not found (expected main package)"; fi; \
	else echo "skip $*: directory services/$* not found"; fi

build/web: ## Build frontend (if apps/web exists)
	@if [ -f apps/web/package.json ]; then \
	  echo ">> building frontend"; \
	  cd apps/web && CI=1 $(PKG_MGR) run build || exit $$?; \
	else echo "skip frontend build (no apps/web/package.json)"; fi

# ===== Docker (root optional + per-service + web) =====
.PHONY: docker docker-build docker-build/services docker-build/% docker-build/root docker-build/web \
        docker-push docker-push/services docker-push/% docker-push/root docker-push/web

DOCKER_BUILD_ARGS ?= \
	--build-arg VERSION=$(VERSION) \
	--build-arg COMMIT=$(GIT_SHA) \
	--build-arg DATE=$(DATE)
OCI_LABELS ?= \
	--label org.opencontainers.image.version=$(VERSION) \
	--label org.opencontainers.image.revision=$(GIT_SHA) \
	--label org.opencontainers.image.created=$(DATE)

docker: docker-build/root docker-build/services docker-build/web ## Build all images

docker-build/root: ## Build root image from ./Dockerfile (if present)
	@if [ -f Dockerfile ]; then \
	  $(DOCKER) build $(DOCKER_BUILD_ARGS) $(OCI_LABELS) \
	    -t $(IMAGE):$(VERSION) -t $(IMAGE):latest . ; \
	else echo "skip root image (no ./Dockerfile)"; fi

docker-build/services: $(SERVICES:%=docker-build/%) ## Build images for all services

.PHONY: docker-build/%
docker-build/%: ## Build specific service image: docker-build/<svc>
	@if [ -f services/$*/Dockerfile ]; then \
	  $(DOCKER) build $(DOCKER_BUILD_ARGS) $(OCI_LABELS) \
	    -f services/$*/Dockerfile \
	    -t $(IMAGE)-$*:$(VERSION) \
	    -t $(IMAGE)-$*:latest \
	    services/$* ; \
	else echo "skip $* (services/$*/Dockerfile not found)"; fi

docker-build/web: ## Build frontend image (if apps/web/Dockerfile exists)
	@if [ -f apps/web/Dockerfile ]; then \
	  [ -f apps/web/package.json ] && (cd apps/web && CI=1 $(PKG_MGR) run build) || true; \
	  $(DOCKER) build $(DOCKER_BUILD_ARGS) $(OCI_LABELS) \
	    -f apps/web/Dockerfile \
	    -t $(IMAGE)-web:$(VERSION) \
	    -t $(IMAGE)-web:latest \
	    apps/web ; \
	else echo "skip web image (no apps/web/Dockerfile)"; fi

docker-push: docker-push/root docker-push/services docker-push/web ## Push all images
docker-push/root:
	@if $(DOCKER) image inspect $(IMAGE):$(VERSION) >/dev/null 2>&1; then \
	  $(DOCKER) push $(IMAGE):$(VERSION) && $(DOCKER) push $(IMAGE):latest; \
	else echo "skip push root (image not found)"; fi

docker-push/services: $(SERVICES:%=docker-push/%)
.PHONY: docker-push/%
docker-push/%:
	@if $(DOCKER) image inspect $(IMAGE)-$*:$(VERSION) >/dev/null 2>&1; then \
	  $(DOCKER) push $(IMAGE)-$*:$(VERSION) && $(DOCKER) push $(IMAGE)-$*:latest; \
	else echo "skip push $* (image not found)"; fi

docker-push/web:
	@if $(DOCKER) image inspect $(IMAGE)-web:$(VERSION) >/dev/null 2>&1; then \
	  $(DOCKER) push $(IMAGE)-web:$(VERSION) && $(DOCKER) push $(IMAGE)-web:latest; \
	else echo "skip push web (image not found)"; fi

# ---- buildx (multi-arch) ----
.PHONY: dockerx-build dockerx-build/services dockerx-build/% dockerx-push dockerx-push/services dockerx-push/%
PLATFORMS ?= linux/amd64,linux/arm64

dockerx-build: dockerx-build/services ## buildx --load (local)
dockerx-build/services: $(SERVICES:%=dockerx-build/%)

dockerx-build/%: ## buildx local: dockerx-build/<svc>
	@if [ -f services/$*/Dockerfile ]; then \
	  docker buildx build --platform $(PLATFORMS) $(DOCKER_BUILD_ARGS) $(OCI_LABELS) \
	    -f services/$*/Dockerfile \
	    -t $(IMAGE)-$*:$(VERSION) \
	    --load services/$* ; \
	else echo "skip $* (services/$*/Dockerfile not found)"; fi

dockerx-push: dockerx-push/services ## buildx --push (to registry)
dockerx-push/services: $(SERVICES:%=dockerx-push/%)

dockerx-push/%: ## buildx push: dockerx-push/<svc>
	@if [ -f services/$*/Dockerfile ]; then \
	  docker buildx build --platform $(PLATFORMS) $(DOCKER_BUILD_ARGS) $(OCI_LABELS) \
	    -f services/$*/Dockerfile \
	    -t $(IMAGE)-$*:$(VERSION) -t $(IMAGE)-$*:latest \
	    --push services/$* ; \
	else echo "skip $* (services/$*/Dockerfile not found)"; fi

# ===== Dev environment (Compose) =====
.PHONY: dev-up dev-down dev-clean dev-restart dev-logs dev-ps dev-rebuild

DEV_SERVICES ?=

dev-up: ## Start local environment (docker compose)
	@if [ -f docker-compose.yml ]; then \
	  $(COMPOSE) up -d $(DEV_SERVICES); \
	else echo "skip dev-up (no docker-compose.yml)"; fi

dev-down: ## Stop containers
	@if [ -f docker-compose.yml ]; then \
	  $(COMPOSE) down; \
	else echo "skip dev-down (no docker-compose.yml)"; fi

dev-clean: ## Stop and remove volumes (warning: data loss)
	@if [ -f docker-compose.yml ]; then \
	  $(COMPOSE) down -v; \
	else echo "skip dev-clean (no docker-compose.yml)"; fi

dev-restart: ## Restart services (or all)
	@if [ -f docker-compose.yml ]; then \
	  $(COMPOSE) restart $(DEV_SERVICES); \
	else echo "skip dev-restart (no docker-compose.yml)"; fi

dev-logs: ## Show logs (tail -100, follow)
	@if [ -f docker-compose.yml ]; then \
	  $(COMPOSE) logs -f --tail=100 $(DEV_SERVICES); \
	else echo "skip dev-logs (no docker-compose.yml)"; fi

dev-ps: ## Show container status
	@if [ -f docker-compose.yml ]; then \
	  $(COMPOSE) ps; \
	else echo "skip dev-ps (no docker-compose.yml)"; fi

dev-rebuild: ## Rebuild images and restart (no cache)
	@if [ -f docker-compose.yml ]; then \
	  $(COMPOSE) build --no-cache $(DEV_SERVICES); \
	  $(COMPOSE) up -d $(DEV_SERVICES); \
	else echo "skip dev-rebuild (no docker-compose

SHELL := /bin/bash

# --- Container engine detection: docker if present, else podman. ---
ENGINE := $(shell command -v docker >/dev/null 2>&1 && echo docker || (command -v podman >/dev/null 2>&1 && echo podman || echo none))
COMPOSE := $(ENGINE) compose

# Has the app actually been built? If so, include it in the stack.
APP_BUILT := $(wildcard target/quarkus-app/quarkus-run.jar)
ifeq ($(APP_BUILT),)
PROFILE_FLAG :=
else
PROFILE_FLAG := --profile app
endif

.DEFAULT_GOAL := help

.PHONY: help check-engine up down restart ps logs build dev test clean psql kafka-topics kafka-console-consumer example example-clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'

check-engine: ## Fail fast with a clear message if neither docker nor podman is installed
ifeq ($(ENGINE),none)
	$(error Neither 'docker' nor 'podman' was found on PATH. See docs/INSTALL.md)
endif
	@:

up: check-engine ## Start the local stack (infra always; app container too once `make build` has run)
	$(COMPOSE) up -d $(PROFILE_FLAG)
ifeq ($(APP_BUILT),)
	@echo ""
	@echo "App not built yet, so only infra containers were started (postgres, adminer, temporal, temporal-ui, kafka, kafka-ui, wiremock)."
	@echo "Run 'make build' then 'make up' again to also start the app container."
else
	@echo ""
	@echo "Full stack is up, including the app container."
endif
	@echo "Temporal UI:  http://localhost:8088"
	@echo "Adminer:      http://localhost:8081  (System: PostgreSQL, Server: postgres, User: app, Password: app, DB: appdb)"
	@echo "Kafka UI:     http://localhost:8089"
	@echo "WireMock:     http://localhost:8090/__admin"

down: check-engine ## Stop the stack, keep volumes (data survives)
	$(COMPOSE) $(PROFILE_FLAG) down

restart: down up ## Restart the stack

ps: check-engine ## Show status of stack containers
	$(COMPOSE) $(PROFILE_FLAG) ps

logs: check-engine ## Tail logs for the whole stack (Ctrl-C to stop)
	$(COMPOSE) $(PROFILE_FLAG) logs -f

build: ## Package the jar and build the app container image
	mvn -q package
	$(COMPOSE) build app

dev: ## Run the app in Quarkus live-coding mode against the stack started by `make up` (needs: mvn, Java 21)
	mvn quarkus:dev

test: ## Run the test suite (Dev Services auto-provision disposable containers; `make up` not required)
	mvn -q test

clean: check-engine ## Stop the stack AND delete its volumes (DESTROYS local Postgres/Kafka/Temporal data)
	$(COMPOSE) $(PROFILE_FLAG) down -v

example: ## Generate a runnable example project in a sibling directory (make example NAME=pizza-maker-simulator DIR=../wherever)
	./scripts/create-example.sh "$(NAME)" "$(DIR)"

example-clean: ## Stop and delete a generated example project (same NAME/DIR as `make example`)
	./scripts/remove-example.sh "$(NAME)" "$(DIR)"

# `compose ps -q <service>` isn't supported by podman-compose, so containers
# are looked up by the standard compose labels instead (set by both docker
# compose and podman-compose), which works the same on both engines.
container_id = $(shell $(ENGINE) ps -q --filter label=com.docker.compose.project=service --filter label=com.docker.compose.service=$(1))

psql: check-engine ## Open a psql shell into the app database
	$(ENGINE) exec -it $(call container_id,postgres) psql -U app -d appdb

kafka-topics: check-engine ## List Kafka topics
	$(ENGINE) exec -it $(call container_id,kafka) /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9092 --list

kafka-console-consumer: check-engine ## Tail a topic: make kafka-console-consumer TOPIC=my-topic
	$(ENGINE) exec -it $(call container_id,kafka) /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic $(TOPIC)

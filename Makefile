include .env
export

COMPOSE = docker compose
GITHUB_API = https://api.github.com

.PHONY: up down destroy status logs ui help

help:
	@echo ""
	@echo "pipeline-lab targets:"
	@echo "  make up       Start all containers (MiniStack + runner + UI)"
	@echo "  make down     Stop containers, preserve state"
	@echo "  make destroy  Deregister runner, remove containers + volumes + state"
	@echo "  make status   Show running container status"
	@echo "  make logs     Tail all container logs"
	@echo "  make ui       Open MiniStack dashboard in browser"
	@echo ""

up:
	@echo "Starting pipeline-lab..."
	$(COMPOSE) up -d
	@echo "Waiting for MiniStack to be healthy..."
	$(COMPOSE) wait ministack
	@echo "pipeline-lab is up."

down:
	@echo "Stopping pipeline-lab (state preserved)..."
	$(COMPOSE) stop
	@echo "Done. Run 'make up' to resume."

destroy:
	@echo "Deregistering GitHub Actions runner..."
	@RUNNER_ID=$$(curl -s -H "Authorization: token $(GITHUB_PAT)" \
		-H "Accept: application/vnd.github+json" \
		"$(GITHUB_API)/repos/$(GITHUB_OWNER)/$(GITHUB_REPO)/actions/runners" \
		| grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*'); \
	if [ -n "$$RUNNER_ID" ]; then \
		curl -s -X DELETE \
			-H "Authorization: token $(GITHUB_PAT)" \
			-H "Accept: application/vnd.github+json" \
			"$(GITHUB_API)/repos/$(GITHUB_OWNER)/$(GITHUB_REPO)/actions/runners/$$RUNNER_ID"; \
		echo "Runner $$RUNNER_ID deregistered."; \
	else \
		echo "No runner found to deregister (may already be removed)."; \
	fi
	@echo "Tearing down containers and volumes..."
	$(COMPOSE) down -v --remove-orphans
	@echo "Removing MiniStack state..."
	rm -rf ./ministack-data
	@echo "Removing runner data..."
	rm -rf ./runner/.runner-data
	@echo "Destroy complete."

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

ui:
	xdg-open http://localhost:8080
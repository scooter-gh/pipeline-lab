include .env
export

COMPOSE = docker compose
GITHUB_API = https://api.github.com
TF_IMAGE = hashicorp/terraform:1.9
TF_NET = pipeline-lab_pipeline-net

.PHONY: up down destroy status logs ui ui-dev bootstrap help

help:
	@echo ""
	@echo "pipeline-lab targets:"
	@echo "  make up         Start all containers (prod + dev MiniStack, runner, UIs)"
	@echo "  make down       Stop containers, preserve state"
	@echo "  make destroy    Deregister runner, remove containers + volumes + state"
	@echo "  make bootstrap  Create tfstate buckets in both MiniStack instances"
	@echo "  make status     Show running container status"
	@echo "  make logs        Tail all container logs"
	@echo "  make ui         Open prod MiniStack dashboard in browser"
	@echo "  make ui-dev     Open dev MiniStack dashboard in browser"
	@echo ""

up:
	@echo "Starting pipeline-lab..."
	$(COMPOSE) up -d
	@echo "Waiting for MiniStack services to be healthy..."
	$(COMPOSE) wait ministack ministack-dev
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
	rm -rf ./ministack-data-dev
	@echo "Removing runner data..."
	rm -rf ./runner/.runner-data
	@echo "Destroy complete."

bootstrap:
	@echo "Bootstrapping prod state bucket (ministack:4566)..."
	docker run --rm --network $(TF_NET) \
		-v $$(pwd)/bootstrap:/workspace -w /workspace \
		$(TF_IMAGE) init -backend=false
	docker run --rm --network $(TF_NET) \
		-v $$(pwd)/bootstrap:/workspace -w /workspace \
		-e AWS_ACCESS_KEY_ID=test -e AWS_SECRET_ACCESS_KEY=test -e AWS_DEFAULT_REGION=us-east-1 \
		$(TF_IMAGE) apply -auto-approve -var="ministack_endpoint=http://ministack:4566"
	@echo "Bootstrapping dev state bucket (ministack-dev:4566)..."
	docker run --rm --network $(TF_NET) \
		-v $$(pwd)/bootstrap:/workspace -w /workspace \
		-e AWS_ACCESS_KEY_ID=test -e AWS_SECRET_ACCESS_KEY=test -e AWS_DEFAULT_REGION=us-east-1 \
		$(TF_IMAGE) apply -auto-approve -var="ministack_endpoint=http://ministack-dev:4566"
	@echo "Bootstrap complete."

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

ui:
	xdg-open http://localhost:8080

ui-dev:
	xdg-open http://localhost:8081
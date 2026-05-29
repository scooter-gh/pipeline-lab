include .env
export

COMPOSE = docker compose
GITHUB_API = https://api.github.com
TF_IMAGE = hashicorp/terraform:1.9
TF_NET = pipeline-lab_pipeline-net
K3D_CLUSTER = pipeline-lab
K8S_NAMESPACE = vote-app

.PHONY: up down destroy status logs ui ui-dev bootstrap help k8s-up k8s-down k8s-status k8s-cli images-build images-import

help:
	@echo ""
	@echo "pipeline-lab targets:"
	@echo "  make up           Start all containers (prod + dev MiniStack, runner, UIs)"
	@echo "  make down         Stop containers, preserve state"
	@echo "  make destroy      Deregister runner, remove containers + volumes + state"
	@echo "  make bootstrap    Create tfstate buckets in both MiniStack instances"
	@echo "  make status       Show running container status"
	@echo "  make logs         Tail all container logs"
	@echo "  make ui           Open prod MiniStack dashboard in browser"
	@echo "  make ui-dev       Open dev MiniStack dashboard in browser"
	@echo "  make k8s-up       Create k3d cluster, wait for readiness"
	@echo "  make k8s-down     Delete k3d cluster"
	@echo "  make k8s-status   Show cluster nodes and pods"
	@echo "  make k8s-cli      Interactive shell with kubectl access"
	@echo "  make images-build Build votes and results container images"
	@echo "  make images-import Import built images into k3d cluster"
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
	@echo "Deleting k3d cluster (if exists)..."
	-$(COMPOSE) exec github-runner k3d cluster delete $(K3D_CLUSTER) 2>/dev/null || true
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

k8s-up:
	@echo "Creating k3d cluster '$(K3D_CLUSTER)'..."
	$(COMPOSE) exec github-runner k3d cluster create $(K3D_CLUSTER) --agents 1 -p "80:80@loadbalancer" --wait
	@echo "Waiting for cluster readiness..."
	$(COMPOSE) exec github-runner sh -c "export KUBECONFIG=\$$(k3d kubeconfig write $(K3D_CLUSTER)) && for i in \$$(seq 1 30); do kubectl get nodes >/dev/null 2>&1 && break; echo \"Waiting for API server... (\$$i/30)\"; sleep 2; done && kubectl wait --for=condition=Ready nodes --all --timeout=120s"
	@echo "k3d cluster is ready."

k8s-down:
	@echo "Deleting k3d cluster '$(K3D_CLUSTER)'..."
	$(COMPOSE) exec github-runner k3d cluster delete $(K3D_CLUSTER) || true
	@echo "k3d cluster deleted."

k8s-status:
	@echo "Cluster nodes:"
	$(COMPOSE) exec github-runner sh -c "export KUBECONFIG=\$$(k3d kubeconfig write $(K3D_CLUSTER)) && kubectl get nodes"
	@echo ""
	@echo "All pods:"
	$(COMPOSE) exec github-runner sh -c "export KUBECONFIG=\$$(k3d kubeconfig write $(K3D_CLUSTER)) && kubectl get pods -A"

k8s-cli:
	@echo "Opening interactive shell in runner with kubectl access..."
	$(COMPOSE) exec -it github-runner sh -c "export KUBECONFIG=\$$(k3d kubeconfig write $(K3D_CLUSTER)) && bash"

images-build:
	@echo "Building votes image..."
	$(COMPOSE) exec github-runner docker build -t votes:latest ./app/votes
	@echo "Building results image..."
	$(COMPOSE) exec github-runner docker build -t results:latest ./app/results

images-import:
	@echo "Importing images into k3d cluster..."
	$(COMPOSE) exec github-runner k3d image import votes:latest results:latest -c $(K3D_CLUSTER)
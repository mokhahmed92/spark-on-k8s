# Makefile for Spark-on-K8s Helm Chart
# Provides convenient commands for chart development and deployment

CHART_NAME := spark-on-k8s
RELEASE_NAME := spark-platform
NAMESPACE := spark-operator
HELM := helm
KUBECTL := kubectl

.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: lint
lint: ## Lint the Helm chart
	$(HELM) lint .

.PHONY: template
template: ## Generate templates without installing
	$(HELM) template $(RELEASE_NAME) . --namespace $(NAMESPACE)

.PHONY: template-debug
template-debug: ## Generate templates with debug output
	$(HELM) template $(RELEASE_NAME) . --namespace $(NAMESPACE) --debug

.PHONY: dry-run
dry-run: ## Perform a dry-run installation
	$(HELM) install $(RELEASE_NAME) . --namespace $(NAMESPACE) --create-namespace --dry-run --debug

.PHONY: install
install: ## Install the chart with default values
	$(HELM) install $(RELEASE_NAME) . --namespace $(NAMESPACE) --create-namespace

.PHONY: install-prod
install-prod: ## Install the chart with production values
	$(HELM) install $(RELEASE_NAME) . --namespace $(NAMESPACE) --create-namespace --values values-prod.yaml

.PHONY: install-dev
install-dev: ## Install the chart with minimal values
	$(HELM) install $(RELEASE_NAME) . --namespace $(NAMESPACE) --create-namespace --values values-dev.yaml

.PHONY: upgrade
upgrade: ## Upgrade the chart
	$(HELM) upgrade $(RELEASE_NAME) . --namespace $(NAMESPACE)

.PHONY: upgrade-prod
upgrade-prod: ## Upgrade the chart with production values
	$(HELM) upgrade $(RELEASE_NAME) . --namespace $(NAMESPACE) --values values-prod.yaml

.PHONY: uninstall
uninstall: ## Uninstall the chart
	$(HELM) uninstall $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: status
status: ## Show release status
	$(HELM) status $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: values
values: ## Show current values
	$(HELM) get values $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: manifest
manifest: ## Show current manifest
	$(HELM) get manifest $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: history
history: ## Show release history
	$(HELM) history $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: rollback
rollback: ## Rollback to previous release
	$(HELM) rollback $(RELEASE_NAME) --namespace $(NAMESPACE)

.PHONY: package
package: ## Package the chart
	$(HELM) package .

.PHONY: deps-update
deps-update: ## Update chart dependencies
	$(HELM) dependency update

.PHONY: deps-build
deps-build: ## Build chart dependencies
	$(HELM) dependency build

.PHONY: verify-volcano
verify-volcano: ## Verify Volcano is installed
	@echo "Checking Volcano installation..."
	@$(KUBECTL) get pods -n volcano-system || echo "Volcano not installed"

.PHONY: install-volcano
install-volcano: ## Install Volcano scheduler
	@echo "Installing Volcano v1.8.2..."
	$(KUBECTL) apply -f https://raw.githubusercontent.com/volcano-sh/volcano/v1.8.2/installer/volcano-development.yaml
	@echo "Waiting for Volcano to be ready..."
	$(KUBECTL) wait --for=condition=ready pod -l app=volcano-scheduler -n volcano-system --timeout=300s

.PHONY: check-namespaces
check-namespaces: ## Check team namespaces
	$(KUBECTL) get namespaces | grep -E "(team-|spark-operator)"

.PHONY: check-quotas
check-quotas: ## Check resource quotas
	$(KUBECTL) get resourcequota -A

.PHONY: check-queues
check-queues: ## Check Volcano queues
	$(KUBECTL) get queues

.PHONY: check-apps
check-apps: ## Check Spark applications
	$(KUBECTL) get sparkapplications -A

.PHONY: logs
logs: ## Show Spark Operator logs
	$(KUBECTL) logs -n $(NAMESPACE) deployment/$(RELEASE_NAME)-spark-operator-controller --follow

.PHONY: test-alpha
test-alpha: ## Submit test job to team-alpha
	$(KUBECTL) apply -f ../../spark-on-k8s/jobs/default-scheduler/team-alpha-pyspark-test.yaml

.PHONY: test-theta
test-theta: ## Submit test job to team-theta (Volcano)
	$(KUBECTL) apply -f ../../spark-on-k8s/jobs/volcano-scheduler/team-theta-spark-volcano.yaml

.PHONY: cleanup-jobs
cleanup-jobs: ## Delete all Spark applications
	$(KUBECTL) delete sparkapplication --all -A

.PHONY: cleanup-all
cleanup-all: uninstall ## Uninstall and delete all resources
	@echo "Deleting team namespaces..."
	$(KUBECTL) delete namespace team-alpha team-beta team-theta team-delta ds-team-ns de-team-ns --ignore-not-found
	@echo "Deleting queues..."
	$(KUBECTL) delete queue --all --ignore-not-found
	@echo "Cleanup complete"

.PHONY: validate
validate: lint template ## Validate chart (lint + template generation)

.PHONY: ci
ci: validate dry-run ## Run CI checks (validate + dry-run)

.PHONY: dev
dev: install check-namespaces check-quotas ## Quick dev setup
	@echo "Development environment ready!"

.PHONY: prod
prod: verify-volcano install-prod check-namespaces check-quotas check-queues ## Production deployment
	@echo "Production environment ready!"

.PHONY: watch-apps
watch-apps: ## Watch Spark applications
	$(KUBECTL) get sparkapplications -A -w

.PHONY: watch-pods
watch-pods: ## Watch pods across all team namespaces
	$(KUBECTL) get pods -A -l spark-role=driver -w

.PHONY: describe-quotas
describe-quotas: ## Describe all resource quotas
	@for ns in team-alpha team-beta team-theta team-delta ds-team-ns de-team-ns; do \
		echo "=== $$ns ===" && $(KUBECTL) describe quota -n $$ns; \
	done

.PHONY: describe-queues
describe-queues: ## Describe all Volcano queues
	@for queue in queue-theta queue-delta batch-jobs-queue default; do \
		echo "=== $$queue ===" && $(KUBECTL) describe queue $$queue; \
	done

.PHONY: repo-add
repo-add: ## Add required Helm repositories
	$(HELM) repo add spark-operator https://kubeflow.github.io/spark-operator
	$(HELM) repo update

.PHONY: pre-install
pre-install: repo-add verify-volcano ## Run pre-installation checks
	@echo "Pre-installation checks complete"

.PHONY: full-install
full-install: pre-install install ## Complete installation with prerequisites
	@echo "Full installation complete"

.PHONY: show-chart-info
show-chart-info: ## Show chart information
	@echo "Chart Name: $(CHART_NAME)"
	@echo "Release Name: $(RELEASE_NAME)"
	@echo "Namespace: $(NAMESPACE)"
	@$(HELM) show chart .

.PHONY: show-values
show-values: ## Show default values
	@$(HELM) show values .

.PHONY: diff
diff: ## Show diff between deployed and local chart (requires helm-diff plugin)
	$(HELM) diff upgrade $(RELEASE_NAME) . --namespace $(NAMESPACE)

.PHONY: deps-list
deps-list: ## List chart dependencies
	$(HELM) dependency list

.PHONY: deps-clean
deps-clean: ## Clean downloaded dependency charts
	rm -rf charts/*.tgz

.PHONY: full-setup
full-setup: repo-add deps-build ## Complete setup (repos + dependencies)
	@echo "Setup complete! Ready to install."

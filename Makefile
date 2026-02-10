# SQL Server Helm Chart - Makefile

.PHONY: help lint test unit-test integration-test helm-test package install uninstall clean

# Default target
help:
	@echo "SQL Server Helm Chart - Available Commands"
	@echo "==========================================="
	@echo ""
	@echo "Testing:"
	@echo "  make lint              - Run Helm lint and YAML validation"
	@echo "  make unit-test         - Run unit tests (no cluster needed)"
	@echo "  make integration-test  - Run integration tests (requires cluster)"
	@echo "  make helm-test         - Run Helm test hook"
	@echo "  make test              - Run all tests"
	@echo ""
	@echo "Deployment:"
	@echo "  make install          - Install chart to cluster"
	@echo "  make upgrade          - Upgrade existing release"
	@echo "  make uninstall        - Uninstall chart from cluster"
	@echo ""
	@echo "Package Management:"
	@echo "  make package          - Package Helm chart"
	@echo "  make index            - Update Helm repository index"
	@echo "  make publish          - Package, index, and update gh-pages"
	@echo ""
	@echo "Utility:"
	@echo "  make clean            - Clean generated files"
	@echo "  make template         - Render templates with default values"
	@echo ""
	@echo "Variables:"
	@echo "  RELEASE_NAME          - Helm release name (default: mssql-test)"
	@echo "  NAMESPACE             - Kubernetes namespace (default: default)"
	@echo "  SA_PASSWORD           - SA password (default: TestP@ssw0rd123!)"
	@echo ""

# Variables
CHART_DIR := sql-server
RELEASE_NAME ?= mssql-test
NAMESPACE ?= default
SA_PASSWORD ?= TestP@ssw0rd123!
REPO_URL := https://mpbravo.github.io/helm-charts/

# Lint targets
lint:
	@echo "Running Helm lint..."
	helm lint $(CHART_DIR)/
	@echo "✓ Lint passed"

validate-yaml:
	@echo "Validating YAML files..."
	@command -v yamllint >/dev/null 2>&1 || (echo "yamllint not found. Install with: pip install yamllint" && exit 1)
	yamllint $(CHART_DIR)/Chart.yaml
	yamllint $(CHART_DIR)/values.yaml
	@echo "✓ YAML validation passed"

validate-schema:
	@echo "Validating JSON schema..."
	python3 -m json.tool $(CHART_DIR)/values.schema.json > /dev/null
	@echo "✓ JSON schema is valid"

# Test targets
unit-test:
	@echo "Running unit tests..."
	@chmod +x tests/unit-tests.sh
	./tests/unit-tests.sh

integration-test:
	@echo "Running integration tests..."
	@chmod +x tests/integration-tests.sh
	TEST_NAMESPACE=$(NAMESPACE) ./tests/integration-tests.sh

helm-test:
	@echo "Running Helm test hook..."
	helm test $(RELEASE_NAME) -n $(NAMESPACE) --timeout 5m

test: lint validate-yaml validate-schema unit-test
	@echo "✓ All fast tests passed!"
	@echo ""
	@echo "To run integration tests (requires cluster):"
	@echo "  make integration-test"

# Template rendering
template:
	@echo "Rendering templates with default values..."
	helm template test-release $(CHART_DIR)/ \
		--set mssql.saPassword='$(SA_PASSWORD)'

template-debug:
	@echo "Rendering templates with debug output..."
	helm template test-release $(CHART_DIR)/ \
		--set mssql.saPassword='$(SA_PASSWORD)' \
		--debug

# Deployment targets
install:
	@echo "Installing chart..."
	helm install $(RELEASE_NAME) $(CHART_DIR)/ \
		--set mssql.saPassword='$(SA_PASSWORD)' \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 5m
	@echo "✓ Chart installed successfully"
	@echo ""
	@echo "Check status with:"
	@echo "  kubectl get all -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME)"

install-dev:
	@echo "Installing chart with development settings..."
	helm install $(RELEASE_NAME) $(CHART_DIR)/ \
		--set mssql.saPassword='$(SA_PASSWORD)' \
		--set MSSQL_PID.value=Developer \
		--set resources.limits.memory=2G \
		--set persistence.size=8Gi \
		--set service.type=ClusterIP \
		--namespace $(NAMESPACE) \
		--create-namespace \
		--wait \
		--timeout 5m

upgrade:
	@echo "Upgrading chart..."
	helm upgrade $(RELEASE_NAME) $(CHART_DIR)/ \
		--set mssql.saPassword='$(SA_PASSWORD)' \
		--namespace $(NAMESPACE) \
		--wait \
		--timeout 5m
	@echo "✓ Chart upgraded successfully"

uninstall:
	@echo "Uninstalling chart..."
	helm uninstall $(RELEASE_NAME) -n $(NAMESPACE)
	@echo "✓ Chart uninstalled"
	@echo ""
	@echo "To also delete the PVC (WARNING: deletes data):"
	@echo "  kubectl delete pvc -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME)"

# Package targets
package:
	@echo "Packaging chart..."
	helm package $(CHART_DIR)/
	@echo "✓ Chart packaged successfully"

index:
	@echo "Updating Helm repository index..."
	helm repo index . --url $(REPO_URL)
	@echo "✓ Repository index updated"

publish: package index
	@echo "Publishing to gh-pages..."
	@echo "Checking if gh-pages branch exists..."
	@git checkout gh-pages || (echo "gh-pages branch not found. Create it first." && exit 1)
	@echo "Copying packaged chart and index..."
	@git checkout main -- index.yaml
	@cp sql-server-*.tgz . 2>/dev/null || true
	@echo "Committing changes..."
	@git add index.yaml sql-server-*.tgz README.md
	@git commit -m "Update Helm repository - automated" || echo "No changes to commit"
	@echo "Pushing to gh-pages..."
	@git push origin gh-pages
	@git checkout main
	@echo "✓ Published to gh-pages"

# Utility targets
clean:
	@echo "Cleaning generated files..."
	rm -f sql-server-*.tgz
	@echo "✓ Cleaned"

status:
	@echo "Release Status:"
	@helm list -n $(NAMESPACE) | grep $(RELEASE_NAME) || echo "Release not found"
	@echo ""
	@echo "Kubernetes Resources:"
	@kubectl get all -n $(NAMESPACE) -l app.kubernetes.io/instance=$(RELEASE_NAME) 2>/dev/null || echo "No resources found"

logs:
	@echo "Fetching logs..."
	@kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=sql-server --tail=100

port-forward:
	@echo "Port forwarding to local port 1433..."
	@echo "Connect with: sqlcmd -S localhost,1433 -U sa -P '$(SA_PASSWORD)'"
	kubectl port-forward -n $(NAMESPACE) service/mssql-deployment 1433:1433

# Quick actions
quick-install: lint template install
	@echo "✓ Quick install complete"

quick-test: lint unit-test install helm-test
	@echo "✓ Quick test complete"

full-test: lint unit-test integration-test
	@echo "✓ Full test suite complete"

# CI/CD simulation
ci: lint validate-yaml validate-schema unit-test
	@echo "✓ CI checks passed"

# Development helpers
dev-install:
	$(MAKE) install-dev RELEASE_NAME=mssql-dev

dev-connect:
	@echo "Connecting to development SQL Server..."
	kubectl run sqlcmd-test --rm -it --image=mcr.microsoft.com/mssql-tools \
		--namespace $(NAMESPACE) \
		--command -- /opt/mssql-tools/bin/sqlcmd \
		-S mssql-deployment,1433 -U sa -P '$(SA_PASSWORD)'

# Documentation
docs:
	@echo "Documentation files:"
	@echo "  README.md                - Main documentation"
	@echo "  OPENSHIFT-GUIDE.md       - OpenShift deployment guide"
	@echo "  ENHANCEMENTS.md          - v0.1.1 enhancements"
	@echo "  tests/README.md          - Testing guide"
	@echo ""
	@echo "Online documentation:"
	@echo "  Chart repository: $(REPO_URL)"
	@echo "  GitHub: https://github.com/mpbravo/helm-charts"

.DEFAULT_GOAL := help

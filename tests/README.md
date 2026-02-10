# SQL Server Helm Chart - Testing Guide

## Overview

This guide covers all testing approaches for the SQL Server Helm chart, including unit tests, integration tests, and manual testing procedures.

## Test Structure

```
tests/
├── unit-tests.sh           # Template validation and chart structure tests
├── integration-tests.sh    # Full deployment and functional tests
└── README.md              # This file

.github/workflows/
└── helm-ci.yml            # Automated CI/CD pipeline
```

## Quick Start

### Run All Tests Locally

```bash
# 1. Run unit tests (fast, no cluster needed)
chmod +x tests/unit-tests.sh
./tests/unit-tests.sh

# 2. Run integration tests (requires Kubernetes/OpenShift cluster)
chmod +x tests/integration-tests.sh
./tests/integration-tests.sh

# 3. Run Helm's built-in test
helm test <release-name>
```

## Test Types

### 1. Unit Tests (`unit-tests.sh`)

**Purpose:** Validate chart structure, templates, and YAML syntax without deploying

**Duration:** ~30 seconds

**Requirements:**
- Helm 3.x
- kubectl (for dry-run validation)
- Python 3 (for JSON validation)

**What it tests:**
- ✅ Chart structure (files exist)
- ✅ YAML syntax validation
- ✅ JSON schema validation
- ✅ Template rendering
- ✅ Helm lint compliance
- ✅ Value overrides
- ✅ Kubernetes manifest validity
- ✅ Metadata completeness
- ✅ Required values enforcement

**Run unit tests:**
```bash
cd /path/to/helm-sqlserver
./tests/unit-tests.sh
```

**Expected output:**
```
========================================
SQL Server Helm Chart - Unit Tests
========================================

1. CHART STRUCTURE TESTS
----------------------------------------
Testing: Chart.yaml exists... ✓ PASSED
Testing: values.yaml exists... ✓ PASSED
Testing: values.schema.json exists... ✓ PASSED
...

TEST SUMMARY
========================================
Passed: 30
Failed: 0
Total:  30

✓ All tests passed!
```

### 2. Integration Tests (`integration-tests.sh`)

**Purpose:** Test actual deployment and SQL Server functionality in a real cluster

**Duration:** ~5-10 minutes

**Requirements:**
- Kubernetes 1.19+ or OpenShift 4.x cluster
- kubectl or oc CLI configured
- Helm 3.x
- Cluster with storage provisioner
- At least 2GB RAM and 2 CPU available

**What it tests:**
- ✅ Chart installation
- ✅ Pod deployment and readiness
- ✅ Service creation
- ✅ PVC binding
- ✅ Secret creation
- ✅ SQL Server connectivity
- ✅ Database operations (CREATE, INSERT, SELECT)
- ✅ Data persistence
- ✅ Resource limits
- ✅ Security context
- ✅ Non-root execution
- ✅ Chart upgrade
- ✅ Data retention after upgrade

**Run integration tests:**
```bash
# For Kubernetes
kubectl config use-context <your-context>
./tests/integration-tests.sh

# For OpenShift
oc login <your-cluster>
./tests/integration-tests.sh

# With custom namespace
TEST_NAMESPACE=testing ./tests/integration-tests.sh
```

**Expected output:**
```
========================================
SQL Server Helm Chart - Integration Tests
========================================

Release Name: test-sqlserver-12345
Namespace: default
Timeout: 300s

1. DEPLOYMENT TESTS
----------------------------------------
Test 1: Installing chart... ✓ PASSED
Testing: Deployment created... ✓ PASSED
...

TEST SUMMARY
========================================
Passed: 25
Failed: 0
Total:  25

✓ All integration tests passed!
```

### 3. Helm Test Hook (`templates/tests/test-connection.yaml`)

**Purpose:** Built-in Helm test that runs after deployment

**Duration:** ~2-3 minutes

**What it tests:**
- ✅ SQL Server version check
- ✅ Server properties
- ✅ Database creation
- ✅ Table creation and data insertion
- ✅ Data querying
- ✅ File persistence location
- ✅ Database cleanup

**Run Helm test:**
```bash
# After installing the chart
helm install mssql sql-server/ --set mssql.saPassword='YourP@ssw0rd'

# Run the test
helm test mssql

# View test results
kubectl logs mssql-sql-server-test-connection
```

**Expected output:**
```
Testing SQL Server connection...
✓ SQL Server is ready and accepting connections
Test 1: Checking SQL Server version...
Test 2: Checking server properties...
Test 3: Creating test database...
Test 4: Creating test table and inserting data...
Test 5: Querying test data...
Test 6: Checking database files location...
Test 7: Cleaning up test database...
✓ All tests passed successfully!
```

### 4. GitHub Actions CI/CD (`helm-ci.yml`)

**Purpose:** Automated testing on every push/PR

**Triggers:**
- Push to main branch
- Pull requests
- Changes to sql-server/ or tests/ directories

**Jobs:**

#### Job 1: Lint and Unit Tests
- YAML linting
- Helm lint
- JSON schema validation
- Template rendering
- Unit test suite

#### Job 2: Integration Tests
- Spin up Kind (Kubernetes in Docker)
- Deploy chart
- Run full integration test suite
- Capture logs on failure

#### Job 3: Security Scan
- Checkov security analysis
- Trivy vulnerability scanning
- Configuration best practices

#### Job 4: Package and Publish
- Package Helm chart
- Update repository index
- Push to gh-pages branch
- Create GitHub release (on tags)

**View CI/CD results:**
- Go to: https://github.com/mpbravo/helm-charts/actions

## Manual Testing Procedures

### Test 1: Basic Installation

```bash
# Install with minimum required values
helm install test-mssql sql-server/ \
  --set mssql.saPassword='TestP@ss123!'

# Verify installation
kubectl get all -l app.kubernetes.io/name=sql-server

# Check logs
kubectl logs -l app.kubernetes.io/name=sql-server --tail=50

# Wait for readiness
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sql-server --timeout=300s
```

### Test 2: Custom Configuration

```bash
# Install with custom values
helm install test-mssql sql-server/ \
  --set mssql.saPassword='TestP@ss123!' \
  --set MSSQL_PID.value=Express \
  --set resources.limits.memory=4G \
  --set persistence.size=20Gi \
  --set service.type=NodePort

# Verify custom values applied
kubectl get deployment -o yaml | grep -A 5 resources
kubectl get pvc
kubectl get service
```

### Test 3: Database Connectivity

```bash
# Get service details
kubectl get service

# Port forward for local testing
kubectl port-forward service/mssql-deployment 1433:1433

# Connect with sqlcmd (in another terminal)
sqlcmd -S localhost,1433 -U sa -P 'TestP@ss123!'

# Or connect from within cluster
kubectl run sqlcmd-test --rm -it --image=mcr.microsoft.com/mssql-tools \
  --command -- /opt/mssql-tools/bin/sqlcmd \
  -S mssql-deployment,1433 -U sa -P 'TestP@ss123!'
```

### Test 4: Data Persistence

```bash
# Create test database
kubectl exec -it <pod-name> -- /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'TestP@ss123!' \
  -Q "CREATE DATABASE PersistenceTest"

# Create table with data
kubectl exec -it <pod-name> -- /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'TestP@ss123!' -d PersistenceTest \
  -Q "CREATE TABLE Test (ID INT, Value VARCHAR(50)); INSERT INTO Test VALUES (1, 'Before restart')"

# Delete pod to trigger restart
kubectl delete pod <pod-name>

# Wait for new pod
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sql-server --timeout=300s

# Verify data persisted
kubectl exec -it <new-pod-name> -- /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'TestP@ss123!' -d PersistenceTest \
  -Q "SELECT * FROM Test"

# Should see: 1 | Before restart
```

### Test 5: Upgrade

```bash
# Perform upgrade with changed values
helm upgrade test-mssql sql-server/ \
  --set mssql.saPassword='TestP@ss123!' \
  --set persistence.size=30Gi

# Check upgrade status
helm history test-mssql

# Verify data still accessible
kubectl exec -it <pod-name> -- /opt/mssql-tools/bin/sqlcmd \
  -S localhost -U sa -P 'TestP@ss123!' \
  -Q "SELECT name FROM sys.databases"
```

### Test 6: OpenShift-Specific

```bash
# Check security context constraints
oc get deployment -o yaml | grep -A 10 securityContext

# Verify non-root execution
oc exec <pod-name> -- id
# Should show UID > 0 (e.g., 10001)

# Check SELinux context (OpenShift)
oc exec <pod-name> -- ls -laZ /var/opt/mssql
```

## Test Coverage

### Chart Components Tested

| Component | Unit Tests | Integration Tests | Helm Test |
|-----------|------------|-------------------|-----------|
| Chart.yaml metadata | ✅ | ✅ | ❌ |
| values.yaml syntax | ✅ | ✅ | ❌ |
| values.schema.json | ✅ | ❌ | ❌ |
| Deployment template | ✅ | ✅ | ✅ |
| Service template | ✅ | ✅ | ✅ |
| PVC template | ✅ | ✅ | ❌ |
| Secret template | ✅ | ✅ | ✅ |
| _helpers.tpl | ✅ | ✅ | ❌ |
| Resource limits | ✅ | ✅ | ❌ |
| Security context | ✅ | ✅ | ❌ |
| SQL Server connectivity | ❌ | ✅ | ✅ |
| Database operations | ❌ | ✅ | ✅ |
| Data persistence | ❌ | ✅ | ✅ |
| Chart upgrade | ❌ | ✅ | ❌ |

### Functional Tests Covered

- ✅ Chart installation
- ✅ Template rendering
- ✅ Pod deployment
- ✅ Service creation
- ✅ Storage provisioning
- ✅ SQL Server startup
- ✅ Database creation
- ✅ Table creation
- ✅ Data insertion
- ✅ Data queries
- ✅ Data persistence across restarts
- ✅ Chart upgrades
- ✅ Resource limits
- ✅ Security contexts
- ✅ Non-root execution

## Troubleshooting Tests

### Unit Tests Failing

**Problem:** Template rendering fails
```bash
# Check specific template
helm template test sql-server/ \
  --set mssql.saPassword='Test123!' \
  --show-only templates/deployment.yaml
```

**Problem:** Lint errors
```bash
# Get detailed lint output
helm lint sql-server/ --debug
```

### Integration Tests Failing

**Problem:** Pod not starting
```bash
# Check pod status
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check logs
kubectl logs <pod-name>
```

**Problem:** SQL Server not accepting connections
```bash
# Check if port is open
kubectl exec <pod-name> -- ss -tuln | grep 1433

# Check SQL Server logs
kubectl logs <pod-name> | grep -i "sql server"

# Verify password
kubectl get secret mssql -o jsonpath='{.data.MSSQL_SA_PASSWORD}' | base64 -d
```

**Problem:** Tests timeout
```bash
# Increase timeout
./tests/integration-tests.sh
# Edit TIMEOUT variable in script

# Or for Helm test
helm test <release-name> --timeout 10m
```

### CI/CD Pipeline Failing

**Check workflow logs:**
- Go to: https://github.com/mpbravo/helm-charts/actions
- Click on failed workflow
- Review job logs

**Common issues:**
- Missing secrets (GITHUB_TOKEN)
- Insufficient cluster resources
- Timeout during SQL Server startup

## Performance Benchmarks

**Expected test durations:**

| Test Type | Duration | Notes |
|-----------|----------|-------|
| Unit tests | 30s | No cluster needed |
| Integration tests (install) | 3-5 min | Includes SQL Server startup |
| Integration tests (full) | 8-10 min | Includes all tests |
| Helm test hook | 2-3 min | After installation |
| CI/CD full pipeline | 15-20 min | All jobs in parallel |

## Continuous Improvement

### Adding New Tests

1. **Unit tests:** Edit `tests/unit-tests.sh`
   - Add new `run_test` or `run_test_with_output` calls
   - Increment test counters

2. **Integration tests:** Edit `tests/integration-tests.sh`
   - Add new test sections
   - Follow existing pattern

3. **Helm test:** Edit `sql-server/templates/tests/test-connection.yaml`
   - Add new SQL commands
   - Update test output

4. **CI/CD:** Edit `.github/workflows/helm-ci.yml`
   - Add new jobs or steps
   - Update matrix for multi-version testing

### Test Automation Best Practices

- ✅ Keep tests idempotent
- ✅ Clean up resources after tests
- ✅ Use unique release names (avoid conflicts)
- ✅ Set appropriate timeouts
- ✅ Capture logs on failures
- ✅ Test both success and failure scenarios
- ✅ Document expected behavior

## Support

For test-related issues:
1. Check this documentation
2. Review test logs
3. Open an issue with:
   - Test output
   - Environment details (Kubernetes version, etc.)
   - Steps to reproduce

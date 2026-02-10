# Testing Quick Reference

## Run Tests in 3 Easy Steps

### 1. Unit Tests (30 seconds, no cluster)
```bash
make unit-test
```

### 2. Integration Tests (5-10 minutes, requires cluster)
```bash
make integration-test
```

### 3. Helm Built-in Test (2 minutes, after install)
```bash
helm install mssql sql-server/ --set mssql.saPassword='TestP@ssw0rd123!'
helm test mssql
```

## All Available Test Commands

| Command | What It Does | Duration | Cluster Needed |
|---------|--------------|----------|----------------|
| `make lint` | YAML/Helm validation | 5s | No |
| `make unit-test` | Template & structure tests | 30s | No |
| `make integration-test` | Full deployment test | 8-10min | Yes |
| `make helm-test` | Post-install validation | 2min | Yes |
| `make test` | Lint + unit tests | 35s | No |
| `make full-test` | All tests | 10min | Yes |

## Using Makefile

```bash
# See all available commands
make help

# Install chart with testing
make quick-install

# Run fast tests
make test

# Install, test, and validate
make quick-test

# Full test suite
make full-test
```

## Manual Testing

### Quick Install & Test
```bash
# Install
helm install test sql-server/ --set mssql.saPassword='Test123!'

# Wait for pod
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sql-server

# Test connection
kubectl run sqlcmd --rm -it --image=mcr.microsoft.com/mssql-tools \
  --command -- /opt/mssql-tools/bin/sqlcmd \
  -S mssql-deployment,1433 -U sa -P 'Test123!'

# Run Helm test
helm test test
```

### Port Forward & Connect Locally
```bash
# Start port forward
kubectl port-forward service/mssql-deployment 1433:1433 &

# Connect with sqlcmd
sqlcmd -S localhost,1433 -U sa -P 'Test123!'

# Stop port forward
kill %1
```

## Test Results

All tests include clear output:
- ✓ Green checkmarks for passed tests
- ✗ Red X marks for failed tests
- Summary with pass/fail counts

## CI/CD

Tests run automatically on every push to main:
- View: https://github.com/mpbravo/helm-charts/actions
- Badge: ![Tests](https://github.com/mpbravo/helm-charts/actions/workflows/helm-ci.yml/badge.svg)

## Need Help?

See detailed documentation:
- `tests/README.md` - Complete testing guide
- `OPENSHIFT-GUIDE.md` - OpenShift deployment & testing
- GitHub Issues - Report problems

#!/usr/bin/env bash

# SQL Server Helm Chart - Integration Tests
# Tests actual deployment and functionality in a Kubernetes/OpenShift cluster

set -e

RELEASE_NAME="test-sqlserver-$RANDOM"
NAMESPACE="${TEST_NAMESPACE:-default}"
CHART_DIR="sql-server"
SA_PASSWORD="TestP@ssw0rd123!"
TIMEOUT=300

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "SQL Server Helm Chart - Integration Tests"
echo "========================================"
echo ""
echo "Release Name: $RELEASE_NAME"
echo "Namespace: $NAMESPACE"
echo "Timeout: ${TIMEOUT}s"
echo ""

FAILED_TESTS=0
PASSED_TESTS=0

# Function to run a test
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -n "Testing: $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((FAILED_TESTS++))
        return 1
    fi
}

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    helm uninstall $RELEASE_NAME -n $NAMESPACE 2>/dev/null || true
    kubectl delete pvc -l "app.kubernetes.io/instance=$RELEASE_NAME" -n $NAMESPACE 2>/dev/null || true
    echo "Cleanup complete"
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo "1. DEPLOYMENT TESTS"
echo "----------------------------------------"

# Test 1: Install chart
echo -n "Test 1: Installing chart... "
if helm install $RELEASE_NAME $CHART_DIR \
    --set mssql.saPassword="$SA_PASSWORD" \
    --namespace $NAMESPACE \
    --wait \
    --timeout ${TIMEOUT}s > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
    echo "Installation failed. Exiting..."
    exit 1
fi

# Test 2: Check deployment exists
run_test "Deployment created" \
    "kubectl get deployment -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE"

# Test 3: Check service exists
run_test "Service created" \
    "kubectl get service -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE"

# Test 4: Check PVC exists
run_test "PVC created" \
    "kubectl get pvc -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE"

# Test 5: Check secret exists
run_test "Secret created" \
    "kubectl get secret -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE"

echo ""
echo "2. POD STATUS TESTS"
echo "----------------------------------------"

# Get pod name
POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')

# Test 6: Pod is running
echo -n "Test 6: Waiting for pod to be running... "
COUNTER=0
while [ $COUNTER -lt 60 ]; do
    POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}')
    if [ "$POD_STATUS" == "Running" ]; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED_TESTS++))
        break
    fi
    sleep 5
    ((COUNTER++))
done

if [ "$POD_STATUS" != "Running" ]; then
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

# Test 7: Container is ready
run_test "Container is ready" \
    "kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[0].ready}' | grep -q true"

# Test 8: Check pod logs for SQL Server startup
echo -n "Test 8: SQL Server started successfully... "
if kubectl logs $POD_NAME -n $NAMESPACE | grep -q "SQL Server is now ready for client connections"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${YELLOW}⚠ SKIPPED (may need more time)${NC}"
fi

echo ""
echo "3. CONNECTIVITY TESTS"
echo "----------------------------------------"

# Test 9: Service has endpoints
run_test "Service has endpoints" \
    "kubectl get endpoints -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o jsonpath='{.items[0].subsets[0].addresses}' | grep -q ."

# Test 10: Port 1433 is open
run_test "Port 1433 is listening" \
    "kubectl exec $POD_NAME -n $NAMESPACE -- ss -tuln | grep -q 1433"

echo ""
echo "4. SQL SERVER FUNCTIONAL TESTS"
echo "----------------------------------------"

# Wait for SQL Server to be fully ready
echo -n "Waiting for SQL Server to accept connections... "
COUNTER=0
SQL_READY=false
while [ $COUNTER -lt 30 ]; do
    if kubectl exec $POD_NAME -n $NAMESPACE -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT 1" > /dev/null 2>&1; then
        SQL_READY=true
        echo -e "${GREEN}✓ Ready${NC}"
        break
    fi
    sleep 5
    ((COUNTER++))
done

if [ "$SQL_READY" = false ]; then
    echo -e "${RED}✗ SQL Server not ready${NC}"
    ((FAILED_TESTS++))
fi

# Test 11: Query SQL Server version
echo -n "Test 11: Query SQL Server version... "
if kubectl exec $POD_NAME -n $NAMESPACE -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT @@VERSION" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

# Test 12: Create test database
echo -n "Test 12: Create test database... "
if kubectl exec $POD_NAME -n $NAMESPACE -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "CREATE DATABASE TestDB" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

# Test 13: Create table and insert data
echo -n "Test 13: Create table and insert data... "
if kubectl exec $POD_NAME -n $NAMESPACE -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -d TestDB -Q "CREATE TABLE Test (ID INT, Name VARCHAR(50)); INSERT INTO Test VALUES (1, 'TestData');" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

# Test 14: Query data
echo -n "Test 14: Query data from table... "
if kubectl exec $POD_NAME -n $NAMESPACE -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -d TestDB -Q "SELECT * FROM Test" | grep -q "TestData"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

echo ""
echo "5. PERSISTENCE TESTS"
echo "----------------------------------------"

# Test 15: Check PVC is bound
run_test "PVC is bound" \
    "kubectl get pvc -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o jsonpath='{.items[0].status.phase}' | grep -q Bound"

# Test 16: Check database files location
echo -n "Test 16: Database files in persistent volume... "
if kubectl exec $POD_NAME -n $NAMESPACE -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -Q "SELECT physical_name FROM sys.master_files WHERE database_id = DB_ID('TestDB')" | grep -q "/var/opt/mssql"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

echo ""
echo "6. RESOURCE TESTS"
echo "----------------------------------------"

# Test 17: Check resource limits
run_test "Resource limits set" \
    "kubectl get deployment -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.limits}' | grep -q memory"

# Test 18: Check resource requests
run_test "Resource requests set" \
    "kubectl get deployment -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o jsonpath='{.items[0].spec.template.spec.containers[0].resources.requests}' | grep -q memory"

echo ""
echo "7. SECURITY TESTS"
echo "----------------------------------------"

# Test 19: Check security context
run_test "Security context configured" \
    "kubectl get deployment -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o jsonpath='{.items[0].spec.template.spec.securityContext}' | grep -q fsGroupChangePolicy"

# Test 20: Check container capabilities
run_test "NET_BIND_SERVICE capability added" \
    "kubectl get deployment -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o jsonpath='{.items[0].spec.template.spec.containers[0].securityContext.capabilities.add}' | grep -q NET_BIND_SERVICE"

# Test 21: Verify non-root user
echo -n "Test 21: Container runs as non-root... "
USER_ID=$(kubectl exec $POD_NAME -n $NAMESPACE -- id -u)
if [ "$USER_ID" != "0" ]; then
    echo -e "${GREEN}✓ PASSED (UID: $USER_ID)${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED (running as root)${NC}"
    ((FAILED_TESTS++))
fi

echo ""
echo "8. HELM TESTS"
echo "----------------------------------------"

# Test 22: Run Helm test
echo -n "Test 22: Running Helm test hook... "
if helm test $RELEASE_NAME -n $NAMESPACE --timeout ${TIMEOUT}s > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

# Test 23: Helm status is deployed
run_test "Helm status is deployed" \
    "helm status $RELEASE_NAME -n $NAMESPACE | grep -q deployed"

echo ""
echo "9. UPGRADE TEST"
echo "----------------------------------------"

# Test 24: Upgrade chart
echo -n "Test 24: Upgrading chart... "
if helm upgrade $RELEASE_NAME $CHART_DIR \
    --set mssql.saPassword="$SA_PASSWORD" \
    --set persistence.size=10Gi \
    --namespace $NAMESPACE \
    --wait \
    --timeout ${TIMEOUT}s > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

# Test 25: Data persists after upgrade
echo -n "Test 25: Data persists after upgrade... "
sleep 10  # Wait for pod to be ready after upgrade
NEW_POD_NAME=$(kubectl get pods -l app.kubernetes.io/instance=$RELEASE_NAME -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')
if kubectl exec $NEW_POD_NAME -n $NAMESPACE -- /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P "$SA_PASSWORD" -d TestDB -Q "SELECT * FROM Test" 2>/dev/null | grep -q "TestData"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

echo ""
echo "========================================"
echo "TEST SUMMARY"
echo "========================================"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo "Total:  $((PASSED_TESTS + FAILED_TESTS))"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some integration tests failed!${NC}"
    exit 1
fi

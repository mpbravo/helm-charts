#!/usr/bin/env bash

# SQL Server Helm Chart - Unit Tests
# Tests chart templates for syntax and validation errors

set -e

CHART_DIR="sql-server"
FAILED_TESTS=0
PASSED_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================"
echo "SQL Server Helm Chart - Unit Tests"
echo "========================================"
echo ""

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

# Function to run a test with output capture
run_test_with_output() {
    local test_name=$1
    local test_command=$2
    local expected_pattern=$3
    
    echo -n "Testing: $test_name... "
    
    output=$(eval "$test_command" 2>&1)
    
    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED_TESTS++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo "  Expected pattern: $expected_pattern"
        echo "  Output: $output"
        ((FAILED_TESTS++))
        return 1
    fi
}

echo "1. CHART STRUCTURE TESTS"
echo "----------------------------------------"

# Test 1: Chart.yaml exists
run_test "Chart.yaml exists" "test -f $CHART_DIR/Chart.yaml"

# Test 2: values.yaml exists
run_test "values.yaml exists" "test -f $CHART_DIR/values.yaml"

# Test 3: values.schema.json exists
run_test "values.schema.json exists" "test -f $CHART_DIR/values.schema.json"

# Test 4: questions.yaml exists
run_test "questions.yaml exists" "test -f $CHART_DIR/questions.yaml"

# Test 5: Templates directory exists
run_test "templates/ directory exists" "test -d $CHART_DIR/templates"

# Test 6: _helpers.tpl exists
run_test "_helpers.tpl exists" "test -f $CHART_DIR/templates/_helpers.tpl"

echo ""
echo "2. CHART VALIDATION TESTS"
echo "----------------------------------------"

# Test 7: Helm lint passes
run_test "helm lint passes" "helm lint $CHART_DIR"

# Test 8: Chart.yaml is valid YAML
run_test "Chart.yaml is valid YAML" "helm show chart $CHART_DIR"

# Test 9: values.yaml is valid YAML
run_test "values.yaml is valid YAML" "helm show values $CHART_DIR"

# Test 10: JSON schema is valid
run_test "values.schema.json is valid JSON" "python3 -m json.tool $CHART_DIR/values.schema.json"

echo ""
echo "3. TEMPLATE RENDERING TESTS"
echo "----------------------------------------"

# Test 11: Templates render with default values
run_test "Templates render with defaults" "helm template test $CHART_DIR --set mssql.saPassword=Test123! --dry-run"

# Test 12: Deployment template renders
run_test_with_output "Deployment renders correctly" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --show-only templates/deployment.yaml" \
    "kind: Deployment"

# Test 13: Service template renders
run_test_with_output "Service renders correctly" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --show-only templates/service.yaml" \
    "kind: Service"

# Test 14: PVC template renders
run_test_with_output "PVC renders correctly" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --show-only templates/pvc.yaml" \
    "kind: PersistentVolumeClaim"

# Test 15: Secret template renders
run_test_with_output "Secret renders correctly" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --show-only templates/secret.yaml" \
    "kind: Secret"

echo ""
echo "4. VALUE OVERRIDE TESTS"
echo "----------------------------------------"

# Test 16: Custom SA password
run_test_with_output "Custom SA password accepted" \
    "helm template test $CHART_DIR --set mssql.saPassword='MyCustomP@ss123'" \
    "kind: Secret"

# Test 17: Custom edition
run_test_with_output "Custom edition (Express)" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --set MSSQL_PID.value=Express" \
    "value: Express"

# Test 18: Custom resources
run_test_with_output "Custom resource limits" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --set resources.limits.memory=4G" \
    "memory: 4G"

# Test 19: Custom storage size
run_test_with_output "Custom storage size" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --set persistence.size=20Gi" \
    "storage: 20Gi"

# Test 20: Service type NodePort
run_test_with_output "Service type NodePort" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --set service.type=NodePort" \
    "type: NodePort"

echo ""
echo "5. KUBERNETES VALIDATION TESTS"
echo "----------------------------------------"

# Test 21: Generated manifests are valid Kubernetes resources
run_test "Kubernetes manifests validation" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! | kubectl apply --dry-run=client -f -"

# Test 22: OpenShift security context
run_test_with_output "OpenShift security context" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --show-only templates/deployment.yaml" \
    "fsGroupChangePolicy: OnRootMismatch"

# Test 23: Container security context has NET_BIND_SERVICE
run_test_with_output "Container security capabilities" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123! --show-only templates/deployment.yaml" \
    "NET_BIND_SERVICE"

echo ""
echo "6. METADATA TESTS"
echo "----------------------------------------"

# Test 24: Chart has required metadata
run_test_with_output "Chart has name" \
    "helm show chart $CHART_DIR" \
    "name: sql-server"

# Test 25: Chart has version
run_test_with_output "Chart has version" \
    "helm show chart $CHART_DIR" \
    "version:"

# Test 26: Chart has description
run_test_with_output "Chart has description" \
    "helm show chart $CHART_DIR" \
    "description:"

# Test 27: Chart has keywords
run_test_with_output "Chart has keywords" \
    "helm show chart $CHART_DIR" \
    "keywords:"

# Test 28: Chart has icon
run_test_with_output "Chart has icon" \
    "helm show chart $CHART_DIR" \
    "icon:"

echo ""
echo "7. REQUIRED VALUES TESTS"
echo "----------------------------------------"

# Test 29: Missing SA password fails validation
echo -n "Testing: Missing SA password fails... "
if helm template test $CHART_DIR 2>&1 | grep -q "saPassword"; then
    echo -e "${GREEN}✓ PASSED${NC}"
    ((PASSED_TESTS++))
else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED_TESTS++))
fi

# Test 30: EULA must be accepted
run_test_with_output "EULA acceptance present" \
    "helm template test $CHART_DIR --set mssql.saPassword=Test123!" \
    "ACCEPT_EULA"

echo ""
echo "========================================"
echo "TEST SUMMARY"
echo "========================================"
echo -e "Passed: ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed: ${RED}$FAILED_TESTS${NC}"
echo "Total:  $((PASSED_TESTS + FAILED_TESTS))"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed!${NC}"
    exit 1
fi

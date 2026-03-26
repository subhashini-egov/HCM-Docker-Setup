#!/bin/bash
# Health check for all HCM local-setup services
set -e

BASE_URL="${BASE_URL:-http://localhost:18000}"
PASS=0
FAIL=0

check() {
  local name=$1
  local path=$2
  if curl -sf "${BASE_URL}${path}" >/dev/null 2>&1; then
    echo "  ✓ ${name}"
    PASS=$((PASS + 1))
  else
    echo "  ✗ ${name}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Infrastructure ==="
echo "(PostgreSQL checked via service connectivity)"

echo ""
echo "=== DIGIT Core Services ==="
check "MDMS" "/mdms-v2/health"
check "User" "/user/health"
check "IDGEN" "/egov-idgen/health"
check "Workflow" "/egov-workflow-v2/health"
check "Localization" "/localization/health"
check "Boundary" "/boundary-service/health"
check "AccessControl" "/access/health"
check "Persister" "/common-persist/health"
check "Filestore" "/filestore/health"
check "ENC" "/egov-enc-service/health"

echo ""
echo "=== HCM Services ==="
check "Project" "/health-project/health"
check "Household" "/household/health"
check "Individual" "/health-individual/health"
check "Facility" "/facility/health"
check "Product" "/product/health"
check "Stock" "/stock/health"
check "Referral Mgmt" "/referralmanagement/health"
check "Plan Service" "/plan-service/health"
check "Census Service" "/census-service/health"
check "Excel Ingestion" "/excel-ingestion/health"
check "Transformer" "/transformer/health"
check "Resource Generator" "/resource-generator/health"
check "Beneficiary IDGen" "/beneficiary-idgen/health"
check "Health HRMS" "/health-hrms/health"
check "Health PGR" "/pgr-services/health"
check "Project Factory" "/project-factory/health"
check "Boundary Mgmt" "/boundary-management/health"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1

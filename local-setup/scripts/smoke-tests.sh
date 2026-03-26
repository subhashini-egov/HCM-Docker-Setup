#!/bin/bash
# Smoke tests for HCM local-setup - validates core API functionality
set -e

BASE_URL="${BASE_URL:-http://localhost:18000}"
TENANT="mz"

echo "=== HCM Smoke Tests ==="

# Test 1: MDMS search
echo -n "MDMS Search... "
RESULT=$(curl -sf -X POST "${BASE_URL}/mdms-v2/v1/_search" \
  -H "Content-Type: application/json" \
  -d '{"RequestInfo":{"apiId":"asset-services","ver":null,"ts":null,"action":null,"did":"1","key":"","msgId":"20170310130900|en_IN","authToken":"","userInfo":{"id":1,"uuid":"1","userName":"admin","type":"EMPLOYEE","tenantId":"mz"}},"MdmsCriteria":{"tenantId":"mz","schemaCode":"tenant.tenants"}}')
echo "$RESULT" | grep -q "tenants" && echo "PASS" || echo "FAIL"

# Test 2: User OAuth token
echo -n "User OAuth... "
TOKEN=$(curl -sf -X POST "${BASE_URL}/user/oauth/token" \
  -H "Authorization: Basic ZWdvdi11c2VyLWNsaWVudDo=" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&scope=read&username=SU-0001&password=eGov@1234&tenantId=${TENANT}&userType=EMPLOYEE" 2>/dev/null)
echo "$TOKEN" | grep -q "access_token" && echo "PASS" || echo "FAIL"

# Test 3: Boundary search
echo -n "Boundary Search... "
RESULT=$(curl -sf "${BASE_URL}/boundary-service/boundary-relationships/_search?tenantId=${TENANT}&hierarchyType=ADMIN&includeChildren=true&boundaryType=Country")
echo "$RESULT" | grep -q "boundary" && echo "PASS" || echo "FAIL"

echo ""
echo "=== Smoke tests complete ==="

#!/bin/bash

###############################################################################
# ELQ-test Application Testing Script
#
# This script tests the deployed FastAPI application by making requests to the
# health and API endpoints. It validates the responses and provides a clear
# pass/fail status report.
#
# Usage: ./test-script.sh
# Author: DevOps Team
# Version: 1.0
###############################################################################

# Set colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

###############################################################################
# FUNCTION: run_tests
# Description: Tests the health and API endpoints of the specified URL
# Parameters:
#   $1 (base_url) - The base URL to test (e.g., http://alb-dns-name)
#   $2 (test_name) - Name identifier for this test run
# Returns:
#   0 if all tests pass, 1 if any test fails
###############################################################################
run_tests() {
  local base_url=$1
  local test_name=$2
  local success=true
  
  echo -e "\n${YELLOW}===== Testing $test_name at $base_url =====${NC}"
  
  # Test health endpoint
  echo -e "\n${YELLOW}Testing /health endpoint...${NC}"
  HEALTH_RESPONSE=$(curl -s "${base_url}/health")
  HEALTH_STATUS=$?
  
  if [ $HEALTH_STATUS -ne 0 ]; then
    echo -e "${RED}❌ Error: Failed to connect to health endpoint${NC}"
    success=false
  elif echo "$HEALTH_RESPONSE" | grep -q "\"status\":\"healthy\""; then
    echo -e "${GREEN}✅ Health check successful${NC}"
    echo -e "${YELLOW}Response:${NC}"
    echo "$HEALTH_RESPONSE" | python3 -m json.tool
  else
    echo -e "${RED}❌ Health check failed${NC}"
    echo -e "${YELLOW}Response:${NC}"
    echo "$HEALTH_RESPONSE"
    success=false
  fi
  
  # Test hello endpoint
  echo -e "\n${YELLOW}Testing /api/hello endpoint...${NC}"
  HELLO_RESPONSE=$(curl -s "${base_url}/api/hello")
  HELLO_STATUS=$?
  
  if [ $HELLO_STATUS -ne 0 ]; then
    echo -e "${RED}❌ Error: Failed to connect to hello endpoint${NC}"
    success=false
  elif echo "$HELLO_RESPONSE" | grep -q "\"message\":\"Hello from Eloquent AI!\""; then
    echo -e "${GREEN}✅ Hello endpoint successful${NC}"
    echo -e "${YELLOW}Response:${NC}"
    echo "$HELLO_RESPONSE" | python3 -m json.tool
  else
    echo -e "${RED}❌ Hello endpoint failed${NC}"
    echo -e "${YELLOW}Response:${NC}"
    echo "$HELLO_RESPONSE"
    success=false
  fi
  
  if [ "$success" = true ]; then
    echo -e "\n${GREEN}✅ All tests passed for $test_name!${NC}"
    return 0
  else
    echo -e "\n${RED}❌ Some tests failed for $test_name${NC}"
    return 1
  fi
}

# Welcome message
echo -e "${YELLOW}==================================================${NC}"
echo -e "${YELLOW}   Eloquent AI Application Testing Script${NC}"
echo -e "${YELLOW}==================================================${NC}"

###############################################################################
# MAIN SCRIPT STARTS HERE
###############################################################################

# Get ALB URL from user
echo -e "\n${YELLOW}Please enter your ALB URL (e.g., http://eloquent-ai-dev-alb-123456789.us-east-1.elb.amazonaws.com):${NC}"
read -p "> " ALB_URL

# Validate input
if [ -z "$ALB_URL" ]; then
  echo -e "${RED}Error: No ALB URL provided${NC}"
  exit 1
fi

# Check if URL starts with http
if [[ ! $ALB_URL == http* ]]; then
  echo -e "${YELLOW}Adding http:// prefix to URL${NC}"
  ALB_URL="http://$ALB_URL"
fi

# Get current git branch
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null)

if [ -n "$GIT_BRANCH" ] && [ -n "$GIT_COMMIT" ]; then
  echo -e "${YELLOW}Testing branch: ${GREEN}$GIT_BRANCH${YELLOW} at commit: ${GREEN}$GIT_COMMIT${NC}"
fi

# Ensure URL doesn't end with a slash
ALB_URL=${ALB_URL%/}

echo -e "\n${YELLOW}Testing application at: ${GREEN}$ALB_URL${NC}"
echo -e "${YELLOW}---------------------------------${NC}"

# Run tests against the ALB URL
run_tests "$ALB_URL" "Deployed ALB"
test_result=$?

# Show test result summary
echo -e "\n${YELLOW}==================================================${NC}"
echo -e "${YELLOW}               Test Summary${NC}"
echo -e "${YELLOW}==================================================${NC}"

if [ "$test_result" -eq 0 ]; then
  echo -e "${GREEN}✅ All tests passed successfully!${NC}"
  
  # Extract environment from response if available
  if echo "$HELLO_RESPONSE" | grep -q "\"environment\":"; then
    ENVIRONMENT=$(echo "$HELLO_RESPONSE" | grep -o '"environment":"[^"]*"' | cut -d'"' -f4)
    echo -e "${YELLOW}Environment: ${GREEN}$ENVIRONMENT${NC}"
  fi
  
  echo -e "${YELLOW}Application is deployed and working correctly at:${NC}"
  echo -e "${GREEN}$ALB_URL${NC}"
  exit 0
else
  echo -e "${RED}❌ Some tests failed. Please check the output above.${NC}"
  exit 1
fi

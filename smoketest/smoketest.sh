#!/usr/bin/env bash

REPO_URL="https://raw.githubusercontent.com/Sundsvallskommun/api-team-tools/refs/heads/main/smoketest/.default.env"

# Check if .env file exists, if not copy from .default.env or pull from GitHub
if [ ! -f ".env" ]; then
    if [ -f ".default.env" ]; then
        echo "Copying local .default.env to .env..."
        cp ".default.env" ".env"
        echo ".env created from local .default.env. Fill in values if necessary."
        exit 1
    else
        echo "No local .default.env found. Fetching from GitHub..."
        curl -f -L "$REPO_URL" -o ".default.env" || {
            echo "Failed to download .default.env from GitHub. Exiting."
            exit 1
        }
        echo ".default.env successfully fetched. Creating .env..."
        cp ".default.env" ".env"
        echo ".env created from GitHub. Fill in any required values and run again."
        exit 1
    fi
fi

# Load environment variables from .env file
set -a
source ".env"
set +a

# Define color variables
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "Select environment:"
echo "1. Lab"
echo "2. Test"
echo "3. Prod"
read -r -p "Enter choice (1, 2, 3): " environment

case "$environment" in
1)
    TOKEN_URL="$LAB_TOKEN_URL"
    API_URL_INTERNAL="$LAB_API_URL_INTERNAL"
    API_URL_EXTERNAL="$LAB_API_URL_EXTERNAL"
    CLIENT_ID="$LAB_CLIENT_ID"
    CLIENT_SECRET="$LAB_CLIENT_SECRET"
    echo "Running smoketest in lab"
    ;;
2)
    TOKEN_URL="$TEST_TOKEN_URL"
    API_URL_INTERNAL="$TEST_API_URL_INTERNAL"
    API_URL_EXTERNAL="$TEST_API_URL_EXTERNAL"
    CLIENT_ID="$TEST_CLIENT_ID"
    CLIENT_SECRET="$TEST_CLIENT_SECRET"
    echo "Running smoketest in test"
    ;;
3)
    TOKEN_URL="$PROD_TOKEN_URL"
    API_URL_INTERNAL="$PROD_API_URL_INTERNAL"
    API_URL_EXTERNAL="$PROD_API_URL_EXTERNAL"
    CLIENT_ID="$PROD_CLIENT_ID"
    CLIENT_SECRET="$PROD_CLIENT_SECRET"
    echo "Running smoketest in production"
    ;;
*)
    echo "Invalid choice"
    exit 1
    ;;
esac

echo "Do you want to provide custom clientId and clientSecret? (y/n)"
read -r -p "Enter choice (y/n): " custom

if [ "$custom" = "y" ]; then
    read -r -p "Enter clientId: " CLIENT_ID
    read -r -p "Enter clientSecret: " CLIENT_SECRET
elif [ "$custom" != "n" ]; then
    echo "Invalid choice"
    exit 1
fi

# Encode clientId and clientSecret in base64
AUTH_HEADER="$(echo -n "$CLIENT_ID:$CLIENT_SECRET" | base64)"

echo "Retrieving token..."
TOKEN="$(curl -s -X POST "$TOKEN_URL" \
    -H "Authorization: Basic $AUTH_HEADER" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=client_credentials" | grep -o '"access_token":"[^"]*' | grep -o '[^"]*$')"

if [ -z "$TOKEN" ]; then
    echo "Failed to retrieve token"
    exit 1
fi

echo "Token retrieved successfully"

echo "Running smoke test..."

for API in "${APIS[@]}"; do
    for GATEWAY in "$API_URL_INTERNAL" "$API_URL_EXTERNAL"; do
        RESPONSE="$(curl -s -w "\n%{http_code}\n%{time_total}" -X GET "${GATEWAY}${API}" \
            -H "Authorization: Bearer $TOKEN")"
        # The last line is time_total
        TIME_TOTAL="$(echo "$RESPONSE" | tail -n1)"
        # The second-to-last line is http_code
        STATUS_CODE="$(echo "$RESPONSE" | tail -n2 | head -n1)"
        # The rest is the body
        BODY="$(echo "$RESPONSE" | sed '$d' | sed '$d')"

        # Service is the second part of the URL
        SERVICE="$(echo "$API" | cut -d'/' -f2)"
        # Version is the third part of the URL
        VERSION="$(echo "$API" | cut -d'/' -f3)"
        ENVIRONMENT=""

        if [ "$GATEWAY" = "$API_URL_INTERNAL" ]; then
            ENVIRONMENT="INTERNAL"
        elif [ "$GATEWAY" = "$API_URL_EXTERNAL" ]; then
            ENVIRONMENT="EXTERNAL"
        fi

        if [[ "$STATUS_CODE" == 2* ]]; then
            echo -e "${GREEN}${SERVICE} - ${VERSION} - ${ENVIRONMENT} - Status code: $STATUS_CODE [OK] Took ${TIME_TOTAL} seconds${NC}"
        else
            DESCRIPTION="$(echo "$BODY" | grep -o '"description":"[^"]*' | grep -o '[^"]*$')"
            echo -e "${RED}${SERVICE} - ${VERSION} - ${ENVIRONMENT} - Status code: $STATUS_CODE [$DESCRIPTION] Took ${TIME_TOTAL} seconds${NC}"
        fi

        echo
    done
done

#!/bin/bash

set -euxo pipefail

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."
TEMP_DIR="${BASE_DIR}/.temp"

if [[ -f "${BASE_DIR}/.env" ]]; then
    # shellcheck source=/dev/null
    source "${BASE_DIR}/.env"
fi

pushd "${TEMP_DIR}" >/dev/null

echo "## Authenticating ..."

HCP_CREDENTIALS_JSON=credentials.json

curl -fsSL "https://auth.idp.hashicorp.com/oauth2/token" \
    --header "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "client_id=${HCP_CLIENT_ID}" \
    --data-urlencode "client_secret=${HCP_CLIENT_SECRET}" \
    --data-urlencode "grant_type=client_credentials" \
    --data-urlencode "audience=https://api.hashicorp.cloud" \
    >"${HCP_CREDENTIALS_JSON}"

ACCESS_TOKEN=$(jq <"${HCP_CREDENTIALS_JSON}" -r '.access_token')

REGISTRY=paullalonde
BOX=amazon-linux-2023
# VERSION=$(jq <setup.json -r '.version')
VERSION="0.2"
PROVIDER=$(jq <box/metadata.json -r '.provider')
ARCHITECTURE=$(jq <setup.json -r '.architecture')

# curl -sSL "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/${REGISTRY}/box/${BOX}/versions" \
#     --header "authorization: Bearer ${ACCESS_TOKEN}" \
#     | jq '.'

# exit 44

echo "## Creating Version ..."

CREATE_VERSION_REQUEST_JSON=create-version-request.json
jq --null-input \
    --arg name "${VERSION}" \
    '{name: $name}' \
    >"${CREATE_VERSION_REQUEST_JSON}"

HTTP_STATUS_TEXT=http-status.txt
CREATE_VERSION_RESPONSE_JSON=create-version-response.json
curl -sSL -X POST "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/${REGISTRY}/box/${BOX}/versions" \
    --header "authorization: Bearer ${ACCESS_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "@${CREATE_VERSION_REQUEST_JSON}" \
    --output "${CREATE_VERSION_RESPONSE_JSON}" \
    -w '%{http_code}' \
    >"${HTTP_STATUS_TEXT}"

HTTP_STATUS=$(<"${HTTP_STATUS_TEXT}")

if [[ "${HTTP_STATUS}" -ne 200 ]] && [[ "${HTTP_STATUS}" -ne 409 ]]; then
    echo "Failed to create version: ${HTTP_STATUS}"
    cat "${CREATE_VERSION_RESPONSE_JSON}"
    exit 20
fi

echo "## Creating Provider ..."

CREATE_PROVIDER_REQUEST_JSON=create-provider-request.json
jq --null-input \
    --arg name "${PROVIDER}" \
    '{name: $name}' \
    >"${CREATE_PROVIDER_REQUEST_JSON}"

CREATE_PROVIDER_RESPONSE_JSON=create-provider-response.json
curl -sSL -X POST "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/${REGISTRY}/box/${BOX}/versions/${VERSION}/providers" \
    --header "authorization: Bearer ${ACCESS_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "@${CREATE_PROVIDER_REQUEST_JSON}" \
    --output "${CREATE_PROVIDER_RESPONSE_JSON}" \
    -w '%{http_code}' \
    >"${HTTP_STATUS_TEXT}"

HTTP_STATUS=$(<"${HTTP_STATUS_TEXT}")

if [[ "${HTTP_STATUS}" -ne 200 ]] && [[ "${HTTP_STATUS}" -ne 409 ]]; then
    echo "Failed to create provider: ${HTTP_STATUS}"
    cat "${CREATE_PROVIDER_RESPONSE_JSON}"
    exit 20
fi

exit 88

https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/paullalonde/box/amazon-linux-2023/versions
https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/paullalonde/box/amazon-linux-2023/versions/2023.6.20241212/providers

# UPLOAD_URL_JSON=upload.json
# curl -fsSL "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/${REGISTRY}/box/${BOX}/version/${VERSION}/provider/${PROVIDER}/architecture/${ARCHITECTURE}/upload" \
#     --header "authorization: Bearer ${ACCESS_TOKEN}" \
#     --header "Content-Type: application/x-www-form-urlencoded" \
#     --data-urlencode "name=${VERSION}" \
#     >"${UPLOAD_URL_JSON}"

popd >/dev/null

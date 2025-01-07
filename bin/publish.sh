#!/bin/bash

set -euo pipefail

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."
TEMP_DIR="${BASE_DIR}/.temp"
BUILD_DIR="${TEMP_DIR}/build"
VMCONF_JSON="${TEMP_DIR}/vm-conf.json"

if [[ -f "${BASE_DIR}/.env" ]]; then
    # shellcheck source=/dev/null
    source "${BASE_DIR}/.env"
fi

pushd "${BUILD_DIR}" >/dev/null

VERSION=$(jq <"${VMCONF_JSON}" -r '.version')
ARCHITECTURE=$(jq <"${VMCONF_JSON}" -r '.architecture')

echo "## Publishing box for Amazon Linux 2023 ${VERSION} ${ARCHITECTURE}"

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
ARCHIVE_NAME="vagrant.box"
PROVIDER=$(jq <box/metadata.json -r '.provider')

echo "## Creating Version ..."

CREATE_VERSION_REQUEST_JSON=create-version-request.json
jq --null-input \
    --arg vers "${VERSION}" \
    '{name: $vers}' \
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
    --arg prov "${PROVIDER}" \
    '{name: $prov}' \
    >"${CREATE_PROVIDER_REQUEST_JSON}"

CREATE_PROVIDER_RESPONSE_JSON=create-provider-response.json
curl -sSL -X POST "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/${REGISTRY}/box/${BOX}/version/${VERSION}/providers" \
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

echo "## Creating Architecture ..."

CREATE_ARCHITECTURE_REQUEST_JSON=create-architecture-request.json
jq --null-input \
    --arg arch "${ARCHITECTURE}" \
    '{architecture_type: $arch}' \
    >"${CREATE_ARCHITECTURE_REQUEST_JSON}"

CREATE_ARCHITECTURE_RESPONSE_JSON=create-architecture-response.json
curl -sSL -X POST "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/${REGISTRY}/box/${BOX}/version/${VERSION}/provider/${PROVIDER}/architectures" \
    --header "authorization: Bearer ${ACCESS_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "@${CREATE_ARCHITECTURE_REQUEST_JSON}" \
    --output "${CREATE_ARCHITECTURE_RESPONSE_JSON}" \
    -w '%{http_code}' \
    >"${HTTP_STATUS_TEXT}"

HTTP_STATUS=$(<"${HTTP_STATUS_TEXT}")

if [[ "${HTTP_STATUS}" -ne 200 ]] && [[ "${HTTP_STATUS}" -ne 409 ]]; then
    echo "Failed to create architecture: ${HTTP_STATUS}"
    cat "${CREATE_ARCHITECTURE_RESPONSE_JSON}"
    exit 20
fi

echo "## Uploading box ..."

DIRECT_UPLOAD_BOX_RESPONSE_JSON=direct-upload-box-response.json
curl -fsSL "https://api.cloud.hashicorp.com/vagrant/2022-09-30/registry/${REGISTRY}/box/${BOX}/version/${VERSION}/provider/${PROVIDER}/architecture/${ARCHITECTURE}/direct/upload" \
    --header "authorization: Bearer ${ACCESS_TOKEN}" \
    --output "${DIRECT_UPLOAD_BOX_RESPONSE_JSON}" \

UPLOAD_URL=$(jq <"${DIRECT_UPLOAD_BOX_RESPONSE_JSON}" -r '.url')
CALLBACK_URL=$(jq <"${DIRECT_UPLOAD_BOX_RESPONSE_JSON}" -r '.callback')

UPLOAD_RESPONSE=upload-response
curl -fSL "${UPLOAD_URL}" \
    --upload-file "${ARCHIVE_NAME}" \
    --output "${UPLOAD_RESPONSE}"

COMPLETE_UPLOAD_RESPONSE_JSON=complete-upload-response.json
curl -fsSL -X PUT "${CALLBACK_URL}" \
    --header "authorization: Bearer ${ACCESS_TOKEN}" \
    --output "${COMPLETE_UPLOAD_RESPONSE_JSON}"

echo "## Done."

popd >/dev/null

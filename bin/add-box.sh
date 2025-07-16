#!/bin/bash

set -euxo pipefail

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."

pushd "${BASE_DIR}" >/dev/null

SETUP_YAML="${BASE_DIR}/setup.yaml"

if [[ -z "${VERSION:-}" ]]; then
    VERSION=$(yq <"${SETUP_YAML}" '.version')
fi

BOX_VENDOR="paullalonde"
BOX_NAME="amazon-linux-2023"

vagrant box add \
    "${BOX_VENDOR}/${BOX_NAME}" \
    --box-version "${VERSION}"

popd >/dev/null

#!/bin/bash

set -euo pipefail

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."
TEMP_DIR="${BASE_DIR}/.temp"
BUILD_DIR="${TEMP_DIR}/build"
VMCONF_JSON="${TEMP_DIR}/vm-conf.json"

pushd "${BUILD_DIR}" >/dev/null

ARCHITECTURE=$(jq <"${VMCONF_JSON}" -r '.architecture')

BOX_VENDOR="paullalonde"
BOX_NAME="amazon-linux-2023"
ARCHIVE_NAME="vagrant.box"

vagrant box add \
    --force \
    --name "${BOX_VENDOR}/${BOX_NAME}" \
    --provider libvirt \
    --architecture "${ARCHITECTURE}" \
    "${BUILD_DIR}/${ARCHIVE_NAME}"

popd >/dev/null

#!/bin/bash

set -euo pipefail

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."
TEMP_DIR="${BASE_DIR}/.temp"
BUILD_DIR="${TEMP_DIR}/build"
BOX_DIR="${BUILD_DIR}/box"
VMCONF_JSON="${TEMP_DIR}/vm-conf.json"

rm -rf "${BUILD_DIR:?}"/*
mkdir -p "${BOX_DIR}"

pushd "${BUILD_DIR}" >/dev/null

VERSION=$(jq <"${VMCONF_JSON}" -r '.version')
ARCHITECTURE=$(jq <"${VMCONF_JSON}" -r '.architecture')

echo "## Building box for Amazon Linux 2023 ${VERSION} ${ARCHITECTURE}"

echo "## Creating box image ..."

DISK_IMAGE="${TEMP_DIR}/disk.qcow2"
BOX_IMAGE="${BOX_DIR}/box.img"

cp "${DISK_IMAGE}" "${BOX_IMAGE}"

echo "## Creating Vagrant box ..."

# 1073741824 = 1024^3
GBSIZE=1073741824
IMG_SIZE=$(qemu-img info --output=json "${BOX_IMAGE}" | jq -r --argjson gb "${GBSIZE}" '."virtual-size"|./$gb|floor')

jq <"${VMCONF_JSON}" \
    --from-file "${BASE_DIR}/templates/metadata.jq" \
    --argjson size "${IMG_SIZE}" \
    >"${BOX_DIR}/metadata.json"

cp \
    "${BASE_DIR}/templates/Vagrantfile" \
    "${BASE_DIR}/templates/info.json" \
    "${BOX_DIR}/"

ARCHIVE_NAME="vagrant.box"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"

rm -f "${ARCHIVE_NAME}" "${CHECKSUM_NAME}"
tar -czf "${ARCHIVE_NAME}" -C box .
sha256sum "${ARCHIVE_NAME}" >"${CHECKSUM_NAME}"

popd >/dev/null

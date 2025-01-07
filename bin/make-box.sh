#!/bin/bash

set -euxo pipefail

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."
TEMP_DIR="${BASE_DIR}/.temp"

pushd "${TEMP_DIR}" >/dev/null

BOX_DIR=box
SETUP_JSON=setup.json

mkdir -p "${BOX_DIR}"
rm -rf "${BOX_DIR:?}"/*

echo "## Creating box image ..."

DISK_IMAGE="${TEMP_DIR}/disk.qcow2"
BOX_IMAGE="${BOX_DIR}/box.img"

cp "${DISK_IMAGE}" "${BOX_IMAGE}"

echo "## Creating Vagrant box ..."

# 1073741824 = 1024^3
GBSIZE=1073741824
IMG_SIZE=$(qemu-img info --output=json "${BOX_IMAGE}" | jq -r --argjson gb "${GBSIZE}" '."virtual-size"|./$gb|floor')

jq <"${SETUP_JSON}" \
    --from-file "${BASE_DIR}/templates/metadata.jq" \
    --argjson size "${IMG_SIZE}" \
    >"${BOX_DIR}/metadata.json"

cp \
    "${BASE_DIR}/templates/Vagrantfile" \
    "${BASE_DIR}/templates/info.json" \
    "${BOX_DIR}/"

ARCHIVE_NAME="box.tgz"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"

rm -f "${ARCHIVE_NAME}" "${CHECKSUM_NAME}"
tar -czf "${ARCHIVE_NAME}" -C box .
sha256sum "${ARCHIVE_NAME}" >"${CHECKSUM_NAME}"

popd >/dev/null

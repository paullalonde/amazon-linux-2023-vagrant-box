#!/bin/bash

set -euxo pipefail

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."
TEMP_DIR="${BASE_DIR}/.temp"

pushd "${TEMP_DIR}" >/dev/null

BOX_VENDOR="paullalonde"
BOX_NAME="amazon-linux-2023"
ARCHIVE_NAME="${BOX_NAME}.tgz"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"
BOX_ARCH=$(jq <box/metadata.json -r '.architecture')

rm -f "${ARCHIVE_NAME}" "${CHECKSUM_NAME}"
tar -czf "${ARCHIVE_NAME}" -C box .
sha256sum "${ARCHIVE_NAME}" >"${CHECKSUM_NAME}"

vagrant box add \
    --force \
    --name "${BOX_VENDOR}/${BOX_NAME}" \
    --provider libvirt \
    --architecture "${BOX_ARCH}" \
    "${ARCHIVE_NAME}"

popd >/dev/null

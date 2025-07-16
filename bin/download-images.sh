#!/bin/bash

set -euo pipefail

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."

usage() {
    echo "usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --version <version>   Specify the version to download"
    exit 1
}

VERSION=''

while [ $# -gt 0 ]
do
    case "$1" in
        --version)
            VERSION="$2"
            shift
            shift
        ;;
        
        *)
            usage
    esac
done

pushd "${BASE_DIR}" >/dev/null

SETUP_YAML="${BASE_DIR}/setup.yaml"

if [[ -z "${VERSION}" ]]; then
    VERSION=$(yq <"${SETUP_YAML}" '.version')
fi

DOWNLOADS_DIR=downloads
VERSION_DIR="${DOWNLOADS_DIR}/${VERSION}"
mkdir -p "${VERSION_DIR}"

VERSION_URL="https://cdn.amazonlinux.com/al2023/os-images/${VERSION}"

for ARCH in arm64 x86_64
do
    case "${ARCH}" in
        x86_64)
            KVM_NAME="kvm"
        ;;
        arm64)
            KVM_NAME="kvm-${ARCH}"
        ;;
    esac

    ARCH_URL="${VERSION_URL}/${KVM_NAME}"
    ARCH_DIR="${VERSION_DIR}/${KVM_NAME}"
    
    mkdir -p "${ARCH_DIR}"

    CHECKSUM_FILE=SHA256SUMS
    SIG_FILE=SHA256SUMS.RSASSA_PKCS1_V1_5_SHA_256
    IMAGE_FILE="al2023-kvm-${VERSION}-kernel-6.1-${ARCH}.xfs.gpt.qcow2"

    for FILE in "${CHECKSUM_FILE}" "${SIG_FILE}" "${IMAGE_FILE}"
    do
        echo "## Downloading ${VERSION_URL}/${KVM_NAME}/${FILE} ..."

        curl -fSL -o "${ARCH_DIR}/${FILE}" "${ARCH_URL}/${FILE}"
    done
done

echo "## Done."

popd >/dev/null

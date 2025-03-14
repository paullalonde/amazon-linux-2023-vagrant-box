#!/bin/bash

set -euo pipefail

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."

pushd "${BASE_DIR}" >/dev/null

SETUP_YAML="${BASE_DIR}/setup.yaml"

ARCHITECTURE=''
INTERACTIVE=''
VERSION=''

while [ $# -gt 0 ]
do
    case "$1" in
        -a|--architecture)
            ARCHITECTURE="$2"
            shift
            shift
        ;;
        
        -i|--interactive)
            INTERACTIVE=1
            shift
        ;;
        
        -v|--version)
            VERSION="$2"
            shift
            shift
        ;;
        
        *)
            usage
    esac
done

if [[ -z "${ARCHITECTURE}" ]]; then
    ARCHITECTURE=$(uname -m | tr '[:upper:]' '[:lower:]')
fi

if [[ -z "${VERSION}" ]]; then
    VERSION=$(yq <"${SETUP_YAML}" '.version')
fi

function wait_for_qemu() {
    set +e
    if [[ -f "${PIDFILE}" ]]; then
        PID=$(<"${PIDFILE}")
        wait "${PID}"
    fi
    set -e
}

TEMP_DIR="${BASE_DIR}/.temp"
mkdir -p "${TEMP_DIR}"
rm -rf "${TEMP_DIR:?}"/*

VMCONF_JSON="${TEMP_DIR}/vm-conf.json"

jq --null-input \
    --arg version "${VERSION}" \
    --arg architecture "${ARCHITECTURE}" \
    '{version: $version, architecture: $architecture}' \
    >"${VMCONF_JSON}"

echo "## Provisioning Amazon Linux 2023 ${VERSION} ${ARCHITECTURE}"

echo "## Locating QEMU ..."

BREW_PREFIX=$(brew config | sed -n 's/^HOMEBREW_PREFIX: //p')
QEMU_SHARE_DIR="${BREW_PREFIX}/share/qemu"

case "${ARCHITECTURE}" in
    arm64)
        BOOT_CODE_NAME="edk2-aarch64-code.fd"
        BOOT_VARS_NAME="edk2-arm-vars.fd"
        QEMU_BINARY_NAME=qemu-system-aarch64
        ;;
    
    X86_64)
        BOOT_CODE_NAME="edk2-x86_64-code.fd"
        BOOT_VARS_NAME="edk2-arm-vars.fd"
        QEMU_BINARY_NAME=qemu-system-x86_64
        ;;
    
    *)
        usage
        ;;
esac

QEMU_BINARY="${BREW_PREFIX}/bin/${QEMU_BINARY_NAME}"

IMAGE_DIR="${IMAGE_DIR:-${HOME}/Downloads}"
IMAGE_NAME=$(jq <"${VMCONF_JSON}" -r '"al2023-kvm-\(.version)-kernel-6.1-\(.architecture).xfs.gpt.qcow2"')
IMAGE_URL=$(jq <"${VMCONF_JSON}" -r --arg name "${IMAGE_NAME}" '"https://cdn.amazonlinux.com/al2023/os-images/\(.version)/kvm-\(.architecture)/\($name)"')
IMAGE_PATH="${IMAGE_DIR}/${IMAGE_NAME}"

echo "## Copying source disk image ..."

DISK_IMAGE="${TEMP_DIR}/disk.qcow2"
cp -X "${IMAGE_PATH}" "${DISK_IMAGE}"
chmod 644 "${DISK_IMAGE}"
xattr -d com.apple.quarantine "${DISK_IMAGE}"

BOOT_CODE="${TEMP_DIR}/${BOOT_CODE_NAME}"
BOOT_VARS="${TEMP_DIR}/${BOOT_VARS_NAME}"

cp "${QEMU_SHARE_DIR}/${BOOT_CODE_NAME}" "${BOOT_CODE}"
cp "${QEMU_SHARE_DIR}/${BOOT_VARS_NAME}" "${BOOT_VARS}"

echo "## Creating seed ISO file ..."

SEED_ISO="${TEMP_DIR}/seed.iso"
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')

case "${OS_NAME}" in
    darwin)
        hdiutil makehybrid \
            -quiet \
            -o "${SEED_ISO}"  \
            -joliet  \
            -iso \
            -default-volume-name CIDATA \
            ./seed/
        ;;

    *)
        echo "Unsupported OS: ${OS_NAME}"
        exit 1
        ;;
esac

# qemu-img convert -f raw -O qcow2 "${SEED_ISO}" "${SEED_PATH}"

echo "## Creating virtual machine ..."

SSH_PORT=61384
MONITOR_SOCKET="${TEMP_DIR}/monitor.sock"
PIDFILE="${TEMP_DIR}/pid"
VM_UUID=$(uuidgen)

QEMU_ARGS=(
    -name "amazon-linux-2023-${VM_UUID}"
    -uuid "${VM_UUID}" 
    -nodefaults 
    -machine virt 
    -accel hvf 
    -cpu host 
    -m 1G 
    -nographic 
    -audio none 
    -device "virtio-net-pci,mac=02:2B:4F:2B:10:77,netdev=net0" 
    -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22" 
    -drive "if=pflash,format=raw,file=${BOOT_CODE},file.locking=off,readonly=on" 
    -drive "if=pflash,format=raw,file=${BOOT_VARS}" 
    -device "virtio-blk-pci,drive=boot,bootindex=0"
    -drive "if=none,media=disk,id=boot,file.filename=${DISK_IMAGE}"
    -device "virtio-blk-pci,drive=seed,bootindex=1"
    -drive "if=none,media=cdrom,id=seed,file.filename=${SEED_ISO}"
    -serial chardev:con
    # -chardev "stdio,id=con,mux=on,signal=off"
    # -chardev "file,id=con,mux=on,path=${TEMP_DIR}/qemu-console.log"
    -D "${TEMP_DIR}/qemu-debug.log"
    -d "cpu_reset,int,guest_errors,mmu,unimp,plugin,strace,page"
    -no-shutdown
    -monitor "unix:${MONITOR_SOCKET},server,nowait"
    -pidfile "${PIDFILE}"
    -daemonize
)

if [[ -n "${INTERACTIVE}" ]]; then
    QEMU_ARGS+=(-chardev "stdio,id=con,mux=on,signal=off")
else
    QEMU_ARGS+=(-chardev "file,id=con,mux=on,path=${TEMP_DIR}/qemu-console.log")
fi

"${QEMU_BINARY}" "${QEMU_ARGS[@]}"

trap 'wait_for_qemu' EXIT

if [[ -n "${INTERACTIVE}" ]]; then
    exit
fi

while [[ ! -S "${MONITOR_SOCKET}" ]]; do
    sleep 2
done

pushd "${BASE_DIR}/ansible" >/dev/null

echo "## Provisioning VM, Phase 1 ..."

ansible-playbook --inventory=inventory.yaml --limit phase1 playbook.yaml

echo "## Provisioning VM, Phase 2 ..."

ansible-playbook --inventory=inventory.yaml --limit phase2 playbook.yaml

popd >/dev/null

# sleep 100000

echo "## Shutting down ..."

echo 'system_powerdown' | socat - "unix-connect:${MONITOR_SOCKET}"

sleep 2

echo 'commit all' | socat - "unix-connect:${MONITOR_SOCKET}"

sleep 2

echo 'quit' | socat - "unix-connect:${MONITOR_SOCKET}"

sleep 2

echo "## Done."

popd >/dev/null

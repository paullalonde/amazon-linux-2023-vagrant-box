#!/bin/bash

set -euo pipefail

function kill_process() {
    local VM_PID=$1
    set +e
    if ps -p "${VM_PID}" ; then
        kill "${VM_PID}"
    fi
    set -e
}

SELF_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BASE_DIR="${SELF_DIR}/.."
TEMP_DIR="${BASE_DIR}/.temp"
VMCONF_JSON="${TEMP_DIR}/vm-conf.json"

VERSION=$(jq <"${VMCONF_JSON}" -r '.version')
ARCHITECTURE=$(jq <"${VMCONF_JSON}" -r '.architecture')

echo "## Testing Amazon Linux 2023 ${VERSION} ${ARCHITECTURE}"

echo "## Locating QEMU ..."

BREW_PREFIX=$(brew config | sed -n 's/^HOMEBREW_PREFIX: //p')

case "${ARCHITECTURE}" in
    arm64)
        BOOT_CODE_NAME="edk2-aarch64-code.fd"
        BOOT_VARS_NAME="edk2-arm-vars.fd"
        QEMU_BINARY_NAME=qemu-system-aarch64
        ;;
    
    *)
        BOOT_CODE_NAME="edk2-${ARCHITECTURE}-code.fd"
        QEMU_BINARY_NAME=qemu-system-${ARCHITECTURE}
        ;;
esac

BOOT_CODE="${TEMP_DIR}/${BOOT_CODE_NAME}"
BOOT_VARS="${TEMP_DIR}/${BOOT_VARS_NAME}"
QEMU_BINARY="${BREW_PREFIX}/bin/${QEMU_BINARY_NAME}"

echo "## Starting virtual machine ..."

SSH_PORT=61384
DISK_IMAGE="${TEMP_DIR}/disk.qcow2"
MONITOR_SOCKET="${TEMP_DIR}/monitor.sock"
PIDFILE="${TEMP_DIR}/pid"

QEMU_ARGS=(
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
    -serial chardev:con
    -chardev "stdio,id=con,mux=on,signal=on"
    -D "${TEMP_DIR}/test-debug.log"
    -d "cpu_reset,int,guest_errors,mmu,unimp,plugin,strace,page"
    -monitor "unix:${MONITOR_SOCKET},server,nowait"
    -pidfile "${PIDFILE}"
)

"${QEMU_BINARY}" "${QEMU_ARGS[@]}"

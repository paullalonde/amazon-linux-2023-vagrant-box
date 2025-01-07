#!/bin/bash

set -euxo pipefail

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
DISK_IMAGE="${TEMP_DIR}/disk.qcow2"
QEMU_INSTALL_JSON="${TEMP_DIR}/qemu-install.json"

OS_ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')

QEMU_VERSION=$(jq <"${QEMU_INSTALL_JSON}" -r '.[0].installed[0].version')
MACOS_VERSION=$(sw_vers --productVersion | jq --raw-input -r 'split(".")[0]')
MACOS_VERSION_NAME=''

case "${MACOS_VERSION}" in
    15)
        MACOS_VERSION_NAME=sequoia
        ;;

    14)
        MACOS_VERSION_NAME=sonoma
        ;;

    *)
        echo "Unsupported macOS version: ${MACOS_VERSION_NAME}"
        exit 1
        ;;
esac

case "${OS_ARCH}" in
    arm64)
        BREW_FILE="arm64_${MACOS_VERSION_NAME}"
        BOOT_NAME="edk2-aarch64-code"
        QEMU_BINARY_NAME=qemu-system-aarch64
        ;;
    
    *)
        BREW_FILE="${MACOS_VERSION_NAME}"
        BOOT_NAME="edk2-${OS_ARCH}-code"
        QEMU_BINARY_NAME=qemu-system-${OS_ARCH}
        ;;
esac

QEMU_CELLAR_PATH=$(jq <"${QEMU_INSTALL_JSON}" -r --arg brew "${BREW_FILE}" '.[0].bottle.stable.files[$brew].cellar')
QEMU_DIR="${QEMU_CELLAR_PATH}/qemu/${QEMU_VERSION}"
QEMU_BIN_DIR="${QEMU_DIR}/bin"
QEMU_SHARE_DIR="${QEMU_DIR}/share/qemu"
QEMU_BINARY="${QEMU_BIN_DIR}/${QEMU_BINARY_NAME}"

echo "## Creating virtual machine ..."

SSH_PORT=61384
MONITOR_SOCKET="${TEMP_DIR}/monitor.sock"
BOOT_FILE="${QEMU_SHARE_DIR}/${BOOT_NAME}.fd"
# VM_UUID=$(uuidgen)

QEMU_ARGS=(
    # -L "${HOME}/Library/Containers/com.utmapp.UTM/Data/Library/Caches/qemu" 
    # -name "amazon-linux-2023-test"
    -nodefaults 
    -machine virt 
    -accel hvf 
    -cpu host 
    -m 1G 
    -nographic 
    -audio none 
    -device "virtio-net-pci,mac=02:2B:4F:2B:10:77,netdev=net0" 
    -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22" 
    -drive "if=pflash,format=raw,unit=0,file.filename=${BOOT_FILE},file.locking=off,readonly=on" 
    # -drive "if=pflash,unit=1,file=${HOME}/Library/Containers/com.utmapp.UTM/Data/Documents/testmv2.utm/Data/efi_vars.fd" 
    -device "virtio-blk-pci,drive=boot,bootindex=0"
    -drive "if=none,media=disk,id=boot,file.filename=${DISK_IMAGE}"
    -serial chardev:con
    -chardev "stdio,id=con,mux=on"
    # -chardev "file,id=con,mux=on,path=${TEMP_DIR}/test-console.log"
    -D "${TEMP_DIR}/test-debug.log"
    -d "cpu_reset,int,guest_errors,mmu,unimp,plugin,strace,page"
    -no-shutdown
    -snapshot
    -monitor "unix:${MONITOR_SOCKET},server,nowait"

    # -S
)

"${QEMU_BINARY}" "${QEMU_ARGS[@]}" #&
VM_PID=$!

echo "## VM PID: ${VM_PID}"

trap 'kill_process ${VM_PID}' EXIT

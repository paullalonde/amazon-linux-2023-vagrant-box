packer {
  required_version = "~> 1.9"

  required_plugins {
    ansible = {
      version = "~> 1"
      source = "github.com/hashicorp/ansible"
    }
    qemu = {
      version = "~> 1"
      source  = "github.com/hashicorp/qemu"
    }
    vagrant = {
      version = "~> 1"
      source = "github.com/hashicorp/vagrant"
    }
  }
}

variable "qemu_binary" {
  description = "The QEMU binary to invoke."
  type        = string
}

variable "qemu_machine_type" {
  description = "The QEMU machine type."
  type        = string
}

variable "seed_url" {
  description = "The URL of the seed ISO image."
  type        = string
}

variable "source_url" {
  description = "The URL of the source disk image."
  type        = string
}

variable "source_checksum" {
  description = "The checksum of the source disk image."
  type        = string
}

# locals {
#   qemu_settings = {
#     arm64 = {
#         binary       = "qemu-system-arm"
#         machine_type = "virt"
#     }
#   }
# }

source "qemu" "vm" {
    qemu_binary          = var.qemu_binary
    # machine_type         = var.qemu_machine_type
    # accelerator          = "hvf"
    disk_image           = true
    iso_url              = var.source_url
    iso_checksum         = "sha256:${var.source_checksum}"
    disable_vnc          = true
    headless             = true
    efi_boot             = true
    output_directory     = "output"
    shutdown_command     = "echo 'packer' | sudo -S shutdown -P now"
    disk_size            = "3G"
    format               = "qcow2"
    ssh_username         = "vagrant"
    ssh_private_key_file = "./keys/vagrant.key.ed25519"
    # ssh_password       = "vagrant"
    ssh_timeout          = "30m"
    vm_name              = "vagrant-box-test"
    # net_device         = "virtio-net"
    # disk_interface     = "virtio"
    # boot_wait          = "10s"
    # boot_command       = ["<esc><esc><enter><wait>"]
    # boot_command       = ["<tab> text ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<enter><wait>"]
    # cd_label           = "cidata"
    # cd_files           = ["./seed/*"]
    # net_device         = "virtio-net-pci"

    qemuargs = [
      ["-nodefaults" ],
      ["-boot", "c"],
      ["-vga", "none" ],
      ["-nographic" ],
      ["-cpu", "host" ],
      ["-smp", "1" ],
      ["-m", "4096" ],
      ["-machine", var.qemu_machine_type ],
      ["-accel", "hvf" ],
      ["-name", "qemu" ],

      #  SSH
      ["-device", "virtio-net-pci,mac=02:2B:4F:2B:10:77,netdev=net0" ],
      ["-netdev", "user,id=net0,hostfwd=tcp::{{ .SSHHostPort }}-:22" ],

      # Disk
      ["-device", "virtio-blk-pci,drive=hdisk,bootindex=0" ],
      ["-drive", "if=none,media=disk,id=hdisk,file.filename=${var.source_url},discard=unmap,detect-zeroes=unmap" ],

      # Seed
      ["-device", "virtio-blk-pci,drive=seed,bootindex=1" ],
      ["-drive", "if=none,media=disk,id=seed,file.filename=${var.seed_url},readonly=on" ],

      # ["-drive", "if=pflash,format=raw,unit=0,file.filename=/Applications/UTM.app/Contents/Resources/qemu/edk2-aarch64-code.fd,file.locking=off,readonly=on" ],
      # ["-drive", "if=pflash,unit=1,file=/Users/paull/Library/Containers/com.utmapp.UTM/Data/Documents/testmv2.utm/Data/efi_vars.fd" ],
      # ["-device", "virtio-blk-pci,drive=drive8B61F2DE-0227-459D-8F17-BE4C1B37F34F,bootindex=0" ]
      # ["-drive", "if=none,media=disk,id=drive8B61F2DE-0227-459D-8F17-BE4C1B37F34F,file.filename=/Users/paull/Library/Containers/com.utmapp.UTM/Data/Documents/testmv2.utm/Data/al2023-kvm-2023.6.20241121.0-kernel-6.1-arm64.xfs.gpt-2.qcow2,discard=unmap,detect-zeroes=unmap" ],
      # ["-device", "virtio-blk-pci,drive=drive7B25ECCC-8066-4688-9465-8D0C96DE1481,bootindex=1" ]
      # ["-drive", "if=none,media=disk,id=drive7B25ECCC-8066-4688-9465-8D0C96DE1481,file.filename=/Users/paull/Library/Containers/com.utmapp.UTM/Data/Documents/testmv2.utm/Data/seed.qcow2,discard=unmap,detect-zeroes=unmap" ],
      # ["-device", "virtio-serial" ]
      # ["-device", "virtserialport,chardev=org.qemu.guest_agent,name=org.qemu.guest_agent.0" ]
      # ["-chardev", "spiceport,name=org.qemu.guest_agent.0,id=org.qemu.guest_agent" ]
      # ["-uuid", "9F6E656D-27D1-40B7-BB13-32B249048F4B" ],
      # ["-device", "virtio-rng-pci"],
    ]

    qemu_img_args {
        resize  = ["--shrink"]
    }
}

# 2024/12/01 15:02:26 packer-plugin-qemu_v1.1.0_x5.0_darwin_arm64 plugin: 2024/12/01 15:02:26 Executing /opt/homebrew/bin/qemu-system-aarch64: []string{
#   "-accel", "hvf", 
#   "-device", "virtio-net-pci,mac=02:2B:4F:2B:10:77,netdev=net0", 
#   "-device", "virtio-blk-pci,drive=hdisk,bootindex=0", 
#   "-drive", "if=none,media=disk,id=hdisk,file.filename=../.temp/disk.qcow2,discard=unmap,detect-zeroes=unmap", 
#   "-boot", "c", 
#   "-vga", "none", 
#   "-cpu", "host", 
#   "-smp", "1", 
#   "-machine", "virt", 
#   "-netdev", "user,id=net0,hostfwd=tcp::4362-:22", 
#   "-name", "qemu", 
#   "-nodefaults", 
#   "-nographic", 
#   "-m", "4096", 
#   "-vnc", "127.0.0.1:24"}

variable "disable_breakpoints" {
  description = "Should breakpoints be disabled?"
  type        = bool
  default     = true
}

build {
  sources = ["source.qemu.vm"]
}


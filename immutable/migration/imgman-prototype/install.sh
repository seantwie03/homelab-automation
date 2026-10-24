#!/usr/bin/env bash
# Installs localhost/workstation-kde to a prototype VM disk with Anaconda,
# booting the netinst ISO's kernel and initrd with prototype.ks injected.
# Usage: install.sh [KICKSTART]. Run boot.sh afterwards to boot the disk.
set -euo pipefail
M=$(dirname "$(readlink -f "$0")")
D=~/.cache/homelab-images/prototype
ISO=~/.cache/homelab-images/iso/Fedora-Everything-netinst-x86_64-44-1.7.iso
W=$D/installer
mkdir -p "$W"
podman start homelab-image-registry >/dev/null
podman push -q --tls-verify=false localhost/workstation-kde \
    docker://127.0.0.1:5000/desktop22/workstation-kde:test
xorriso -osirrox on -indev "$ISO" \
    -extract /images/pxeboot/vmlinuz "$W/vmlinuz" \
    -extract /images/pxeboot/initrd.img "$W/initrd.img" >/dev/null 2>&1
chmod u+w "$W/vmlinuz" "$W/initrd.img"
cp "${1:-$M/prototype.ks}" "$W/ks.cfg"
(cd "$W" && echo ks.cfg | cpio -o -H newc --quiet) | cat "$W/initrd.img" - >"$W/initrd-ks.img"
cp /usr/share/edk2/ovmf/OVMF_VARS.fd "$D/OVMF_VARS.fd"
chmod u+w "$D/OVMF_VARS.fd"
rm -f "$D/disk.qcow2" "$D/data.qcow2"
qemu-img create -q -f qcow2 "$D/disk.qcow2" 40G
qemu-img create -q -f qcow2 "$D/data.qcow2" 10G
start=$(date +%s)
qemu-system-x86_64 \
    -machine q35,accel=kvm -cpu host -smp 4 -m 6G \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file="$D/OVMF_VARS.fd" \
    -drive if=virtio,format=qcow2,file="$D/disk.qcow2" \
    -drive if=virtio,format=qcow2,file="$D/data.qcow2" \
    -drive media=cdrom,readonly=on,file="$ISO" \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
    -kernel "$W/vmlinuz" -initrd "$W/initrd-ks.img" \
    -append "inst.ks=file:/ks.cfg inst.stage2=hd:LABEL=Fedora-E-dvd-x86_64-44 inst.text console=ttyS0 imgman.url=10.0.2.2:5000/desktop22/workstation-kde:test imgman.disk=vda imgman.insecure-registry=10.0.2.2:5000" \
    -display none -serial file:"$D/install-console.log" -no-reboot
echo "installed in $(($(date +%s) - start))s"

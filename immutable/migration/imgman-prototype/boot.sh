#!/usr/bin/env bash
# Boots the prototype disk through a throwaway overlay, headless but with
# virtio-vga, and the credentials imgman will pass. Usage: boot.sh [fresh|installer]
set -euo pipefail
D=~/.cache/homelab-images/prototype
R=$D/run
vars=${1:-fresh}
rm -rf "$R" && mkdir -m 0700 "$R"
ssh-keygen -q -t ed25519 -N '' -C proto -f "$R/id_ed25519"
qemu-img create -q -f qcow2 -b "$D/disk.qcow2" -F qcow2 "$R/overlay.qcow2"
qemu-img create -q -f qcow2 -b "$D/data.qcow2" -F qcow2 "$R/data-overlay.qcow2"
if [ "$vars" = fresh ]; then
    cp /usr/share/edk2/ovmf/OVMF_VARS.fd "$R/OVMF_VARS.fd"
else
    cp "$D/OVMF_VARS.fd" "$R/OVMF_VARS.fd"
fi
chmod u+w "$R/OVMF_VARS.fd"
key=$(base64 -w0 <"$R/id_ed25519.pub")
tmpfiles=$(printf 'd /var/roothome 0700 root root -\nd /var/roothome/.ssh 0700 root root -\nf+~ /var/roothome/.ssh/authorized_keys 0600 root root - %s\n' "$key" | base64 -w0)
dropin=$(printf '[Unit]\nConditionVirtualization=!vm\n' | base64 -w0)
cid=$((RANDOM % 60000 + 1000))
echo "$cid" >"$R/cid"
qemu-system-x86_64 \
    -machine q35,accel=kvm -cpu host -smp 4 -m 6G \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/ovmf/OVMF_CODE.fd \
    -drive if=pflash,format=raw,file="$R/OVMF_VARS.fd" \
    -drive if=virtio,format=qcow2,file="$R/overlay.qcow2" \
    -drive if=virtio,format=qcow2,file="$R/data-overlay.qcow2" \
    -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
    -device vhost-vsock-pci,guest-cid="$cid" \
    -device virtio-vga \
    -smbios "type=11,value=io.systemd.credential.binary:tmpfiles.extra=$tmpfiles" \
    -smbios "type=11,value=io.systemd.credential:system.hostname=desktop22" \
    -smbios "type=11,value=io.systemd.credential.binary:systemd.unit-dropin.ansible-pull.service=$dropin" \
    ${SPICE:+-spice unix=on,addr=$R/spice.sock,disable-ticketing=on -device virtio-serial -chardev spicevmc,id=vdagent,name=vdagent -device virtserialport,chardev=vdagent,name=com.redhat.spice.0} \
    -display none -serial file:"$R/console.log" \
    -daemonize -pidfile "$R/qemu.pid"
echo "booted cid=$cid pid=$(cat "$R/qemu.pid")"

# x1carbon23 install runbook

Installs x1carbon23 from `ghcr.io/seantwie03/workstation-kde:stable` with
Secure Boot on and its disk encrypted with LUKS2, unlocked by TPM2 + PIN
([D8](../docs/architecture.md#d8-full-disk-encryption)).

**Status:** draft. Every step up to the first boot runs in the x1carbon23 VM
with `imgman`. Steps marked **(hardware)** have not run yet: the firmware
settings, the system disk's path, and TPM enrollment.

## Before the install day

1. `imgman test image x1carbon23` passes on the build `:stable` points to.
2. Write the Fedora 44 netinst ISO, verified as described in "Installer ISO"
   in `immutable/imgman/README.md`, to a USB stick. Fedora Media Writer works,
   or, with the stick's device from `lsblk`:

   ```sh
   sudo dd if=Fedora-Everything-netinst-x86_64-44-1.7.iso of=/dev/sdX bs=4M status=progress conv=fsync
   ```

3. Choose the LUKS passphrase and store it in 1Password. It stays the
   fallback after TPM enrollment, so make it strong.

## Firmware (hardware)

Press `F1` at power-on for the BIOS setup.

1. Set a supervisor password and store it in 1Password.
2. Turn Secure Boot on. If the install USB does not boot with Secure Boot on,
   enable "Allow Microsoft 3rd Party UEFI CA": Fedora's shim is signed with
   that CA, and Secured-core ThinkPads ship with it off.

## Read the system disk's path (hardware)

Boot the USB stick (`F12` for the boot menu), start "Install Fedora", and
switch to a shell with `Ctrl+Alt+F2`, or boot any Fedora live image:

```sh
ls -l /dev/disk/by-id/ | grep nvme
```

Use the `nvme-<model>_<serial>` entry that points at the whole disk, such as
`../../nvme0n1`: not an `-part` entry, and not the `nvme-eui.` alias. Replace
`disk/by-id/placeholder` in `immutable/images/kickstart/x1carbon23.ks` with
`disk/by-id/<that entry>`, run `imgman test image x1carbon23`, and commit and
push it. Until then, the placeholder fails `%pre`'s disk check, so the install
stops before touching any disk.

## Install

1. Connect the laptop to the docking station's Ethernet port. The installer
   pulls the image over the network.
2. Boot the USB stick. At the GRUB menu, highlight "Install Fedora", press
   `e`, and append to the `linux` line:

   ```text
   inst.ks=https://raw.githubusercontent.com/seantwie03/homelab-automation/main/immutable/images/kickstart/x1carbon23.ks
   ```

   Press `Ctrl+X` to boot.
3. Anaconda asks for the LUKS passphrase twice: "Please provide a default LUKS
   passphrase for all devices you want to encrypt."
4. The install wipes the system disk, pulls the image, and reboots.

## First boot

1. Enter the LUKS passphrase at the boot prompt.
2. Log in as `sean` with the bootstrap password, and change it at once with
   `passwd`. The bootstrap hash is public in the kickstart.
3. Run `ansible-pull` once; the timer takes over from then on:

   ```sh
   sudo env ANSIBLE_CONFIG=/opt/homelab-automation/immutable/ansible.cfg \
       ansible-pull \
       --limit localhost \
       --directory /opt/homelab-automation \
       --url https://github.com/seantwie03/homelab-automation.git \
       immutable/x1carbon23.yml
   ```

## TPM2 + PIN (hardware)

The LUKS2 container is the system disk's third partition, after the EFI
partition and `/boot`:

```sh
disk=/dev/disk/by-id/<the entry from above>-part3
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-with-pin=yes --tpm2-pcrs=7 "$disk"
sudo systemd-cryptenroll --recovery-key "$disk"
```

Store the recovery key in 1Password. Reboot: the boot should ask for the PIN,
not the passphrase.

If it still asks for the passphrase, the image's initramfs did not try the
TPM2 token. It never sees `/etc/crypttab`, so add the option on the kernel
command line, keeping `discard`:

```sh
sudo rpm-ostree kargs --replace=rd.luks.options=discard=discard,tpm2-device=auto
```

Then record the kernel argument in the kickstart's `bootloader --append`, so
the next install gets it.

### After a Secure Boot change

Anything that changes PCR 7, such as a Secure Boot database update from
`fwupd` or toggling Secure Boot, makes the TPM refuse. Unlock once with the
recovery key, then enroll again:

```sh
sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto --tpm2-with-pin=yes --tpm2-pcrs=7 "$disk"
```

## Check

```sh
mokutil --sb-state                                    # SecureBoot enabled
bootc status                                          # ghcr.io/seantwie03/workstation-kde:stable
systemctl is-enabled bootc-fetch-apply-updates.timer  # enabled: updates stage, never reboot
h                                                     # ansible-pull.service status
sudo cryptsetup luksDump "$disk" | grep systemd-tpm2  # the TPM2 token
```

Then run Phase 4's checks on the hardware.

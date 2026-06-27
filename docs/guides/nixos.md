# NixOS Install

## Partition

```sh
fdisk /dev/nvme0n1
# delete all existing partitions
# create three partitions
n
[Enter]
[Enter]
+4G
t
1
n
[Enter]
[Enter]
+300G
n
[Enter]
[Enter]
[Enter]
w
```

## Format

```sh
mkfs.fat -F 32 -n boot /dev/nvme0n1p1
mkfs.ext4 -L nixos /dev/nvme0n1p3
```

```sh
zpool create \
-O compression=lz4 \
-O acltype=posixacl \
-O xattr=sa \
-O relatime=on \
-o autotrim=on \
-m none \
-o ashift=12 \
zpool \
/dev/nvme0n1p2

zfs create -o mountpoint=legacy zpool/home
```

## Mount

```sh
mount /dev/disk/by-label/nixos /mnt
mkdir /mnt/boot
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
mkdir /mnt/home
mount -t zfs zpool/home /mnt/home
```

## Install

```sh
nixos-generate-config --root /mnt
# modify /mnt/root/etc/nixos/configuration.nix
head -c 8 /etc/machine-id # set value as networking.hostId
nixos-install
# You will be prompted for root password at the very end
zpool export zpool
umount /mnt/boot
umount /mnt
```

## Login as Root

Press CTRL+ALT+F2
Login as root.

```sh
passwd sean
# enter password
```

## Wifi

```sh
nmcli dev wifi connect Wit --ask
```

## Snapshot

Take a snapshot of the home dir prior to messing around

```sh
zfs snapshot zpool/home@"$(hostname)"-"$(date +%y%m%dT%H:%M)"-fresh_install
# verify
zfs list -t snapshot
```

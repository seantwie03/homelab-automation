# Installs desktop25, a workstation, on its hardware or as an imgman VM.
#
# %pre reads three optional kernel arguments, each on its own:
#   imgman.url                the image to install
#   imgman.disk               the system disk, relative to /dev
#   imgman.insecure-registry  a registry to reach over plain HTTP
# imgman passes all three to install from its test registry onto a VM's disk.
# Without them, %pre uses this host's published image and system disk, which
# are placeholders until images are published, and verifies TLS.
text
lang en_US.UTF-8
keyboard us
timezone America/Chicago --utc
network --bootproto=dhcp --activate --hostname=desktop25
rootpw --lock
# A bootstrap password, published with this file. Change it at first login.
user --name=sean --uid=1000 --gid=1000 --groups=wheel --iscrypted --password=$y$j9T$d7zLGmZwspvuPbCe750ya/$NPPNjIoTofZbVBZv4fdXjiW73H1feqMszK7e31vgg5A

%pre --erroronfail --log=/tmp/pre.log
# Prints the value of kernel argument $1, a sed pattern, or nothing.
arg() {
    sed -n "s/.*\(^\| \)$1=\([^ ]*\).*/\2/p" /proc/cmdline
}
url=$(arg 'imgman\.url')
url=${url:-ghcr.io/seantwie03/workstation-kde:placeholder}
disk=$(arg 'imgman\.disk')
disk=${disk:-disk/by-id/placeholder}
insecure=$(arg 'imgman\.insecure-registry')
if [ -n "$insecure" ]; then
    mkdir -p /etc/containers/registries.conf.d
    printf '[[registry]]\nlocation = "%s"\ninsecure = true\n' "$insecure" \
        >/etc/containers/registries.conf.d/50-imgman.conf
fi
# clearpart wipes this disk, so stop before Anaconda touches any disk if it
# does not exist.
if [ ! -b "/dev/$disk" ]; then
    echo "system disk /dev/$disk does not exist" >&2
    exit 1
fi
cat >/tmp/target.ks <<EOF
ostreecontainer --url=$url --no-signature-verification
ignoredisk --only-use=$disk
EOF
%end

%include /tmp/target.ks

zerombr
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part btrfs.01 --fstype=btrfs --grow
btrfs none --label=fedora btrfs.01
btrfs / --subvol --name=root LABEL=fedora
btrfs /var --subvol --name=var LABEL=fedora
btrfs /var/home --subvol --name=home LABEL=fedora
# btrfs takes compress from the filesystem's first mount, which is the
# initramfs mounting root from the kernel command line. The initramfs combines
# this rootflags with the one Anaconda writes, whichever comes first.
bootloader --append="rootflags=subvol=root,compress=zstd:1"

%post --erroronfail --log=/root/ks-post.log
# Directories that home snapshots exclude are nested subvolumes. Anaconda's
# user command has already created /var/home/sean.
home=/var/home/sean
mkdir -p "$home/.local/share"
btrfs subvolume create "$home/.cache" "$home/.local/share/containers" \
    "$home/Downloads"
chown sean:sean "$home/.local" "$home/.local/share" "$home/.cache" \
    "$home/.local/share/containers" "$home/Downloads"
chmod 0700 "$home/.local" "$home/.local/share" "$home/.cache" \
    "$home/.local/share/containers"
chmod 0755 "$home/Downloads"
restorecon -R "$home"
# bootc mounts / from the kernel command line. Anaconda's / entry makes
# systemd-remount-fs fail on the composefs root.
sed -i '\|^UUID=[^ ]* / btrfs |d' /etc/fstab
# Anaconda points default.target at multi-user.target after a text install.
# Remove the link so the image's default applies.
rm -f /etc/systemd/system/default.target
# The kickstart creates the user, so KDE's first-boot wizard must not run.
touch /etc/plasma-setup-done
%end

reboot

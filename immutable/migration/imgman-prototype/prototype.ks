# Prototype kickstart for imgman (Phase 2). Not a production kickstart.
text
lang en_US.UTF-8
keyboard us
timezone America/Chicago --utc
network --bootproto=dhcp --activate
rootpw --lock
user --name=sean --uid=1000 --gid=1000 --groups=wheel --lock

%pre --erroronfail --log=/tmp/pre.log
set -x
url=$(sed -n 's/.*imgman\.url=\([^ ]*\).*/\1/p' /proc/cmdline)
if [ -n "$url" ]; then
    disk=$(sed -n 's/.*imgman\.disk=\([^ ]*\).*/\1/p' /proc/cmdline)
    mkdir -p /etc/containers/registries.conf.d
    printf '[[registry]]\nlocation = "%s"\ninsecure = true\n' "${url%%/*}" \
        >/etc/containers/registries.conf.d/50-imgman.conf
else
    url=ghcr.io/seantwie03/workstation-kde:stable
    disk=disk/by-id/nvme-EXAMPLE
fi
cat >/tmp/target.ks <<EOT
ostreecontainer --url=$url --no-signature-verification
ignoredisk --only-use=$disk
EOT
cat /tmp/target.ks
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

%post --erroronfail --log=/root/ks-post.log
set -x
# Anaconda's user command has already created /var/home/sean.
btrfs subvolume create /var/home/sean/.cache
chown sean:sean /var/home/sean/.cache
chmod 0700 /var/home/sean/.cache
restorecon -R /var/home/sean
# bootc mounts / from the kernel command line; Anaconda's / entry makes
# systemd-remount-fs fail on the composefs root.
sed -i '\|^UUID=[^ ]* / btrfs |d' /etc/fstab
# Anaconda points default.target at multi-user.target for a text install;
# let the image's default apply.
rm -f /etc/systemd/system/default.target
# The kickstart creates the user, so skip KDE's first-boot wizard.
touch /etc/plasma-setup-done
cat /etc/fstab
btrfs subvolume list /var/home
ls -laZ /var/home/sean
%end

reboot

#!/usr/bin/env bash
# Installs 1Password and its CLI from 1Password's repository, then adapts what
# their install scripts assume about a writable system:
# - They install to /opt, which bootc images link to /var/opt. bootc copies
#   /var only at install, so the files move to /usr/lib/1Password, and
#   systemd-tmpfiles links /opt/1Password to them at boot.
# - They create groups with groupadd, which would take the first regular group
#   ID, the one the kickstart gives sean. The groups are created first with
#   fixed system IDs, which sysusers.d declares again for every boot, so the
#   setgid binaries' group owners always resolve.
# - They write the polkit policy's owners from the users in /etc/passwd, and
#   an image build has none. Every host's user is UID 1000 (the kickstart's
#   user line), so the policy names that UID.
set -euo pipefail

key=/etc/pki/rpm-gpg/RPM-GPG-KEY-1password
fingerprint=3FEF9748469ADBE15DA7CA80AC2D62742012EA22

install -m 0644 /tmp/keys/1password.asc "$key"
# /root links to /var/roothome, which an image build lacks, so gpg gets a
# throwaway home for reading the key.
gnupghome=$(mktemp -d)
actual=$(GNUPGHOME="$gnupghome" gpg --show-keys --with-colons "$key" |
    awk -F: '/^fpr/ { print $10; exit }')
rm -rf "$gnupghome"
if [ "$actual" != "$fingerprint" ]; then
    echo "1Password's key has fingerprint $actual, expected $fingerprint" >&2
    exit 1
fi
rpm --import "$key"
cat >/etc/yum.repos.d/1password.repo <<CONF
[1password]
name=1Password Stable Channel
baseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=file://$key
CONF

# Below Fedora's dynamically allocated system groups, which count down from
# 999, and below regular users, which count up from 1000.
declare -A gids=([onepassword]=450 [onepassword-cli]=451 [onepassword-mcp]=452)
for group in "${!gids[@]}"; do
    groupadd --system --gid "${gids[$group]}" "$group"
    echo "g $group ${gids[$group]}" >>/usr/lib/sysusers.d/onepassword.conf
done

mkdir -p /var/opt
dnf install -y 1password 1password-cli
dnf clean all

mv /var/opt/1Password /usr/lib/1Password
echo "L /var/opt/1Password - - - - /usr/lib/1Password" >/usr/lib/tmpfiles.d/onepassword.conf

policy=/usr/share/polkit-1/actions/com.1password.1Password.policy
sed -i 's|<annotate key="org.freedesktop.policykit.owner">[[:space:]]*</annotate>|<annotate key="org.freedesktop.policykit.owner">unix-user:1000</annotate>|' "$policy"
if ! grep -q 'policykit.owner">unix-user:1000<' "$policy"; then
    echo "1Password's polkit policy has no owner annotation to fill in" >&2
    exit 1
fi

# The packages' install scripts rewrite the repository file with a remote key,
# and hosts never install packages, so it goes.
rm -f /etc/yum.repos.d/1password.repo
# bootc copies /var from the image only on first install, so leave nothing
# there or in /run.
rm -rf /var/opt /var/log/dnf5.log /var/cache/libdnf5 /var/cache/ldconfig /var/lib/dnf \
    /run/dnf

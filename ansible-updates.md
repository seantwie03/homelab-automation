# Ansible Updates

In the [README](./README.md) I install ansible and ansible-lint with `sudo pip`. I do this because the ansible-pull service runs as root. I would prefer to install ansible using `dnf`, but the version packaged in Fedora does not include ansible-pull.

I want to apply regular security updates to these packages, but I want to be more controlled with feature updates. Maybe I want something like what package.json does on the node side, where I specify the major and minor version and let the patch version constantly update.

The first question is, does ansible follow semver?

The second question is what would it look like to implement this in ansible?

The third question is what would the workflow be to identify a new ansible version and update to it?

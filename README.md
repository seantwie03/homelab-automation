# Homelab Automation

Hello,

You've found my homelab-automation repository. It is pretty specific to my workflows, but I've made it open-source because there may be some concepts or ideas that could be useful for others.

## Automation Workflow

This automation workflow is built around [Ansible](https://ansible.readthedocs.io/) and [ansible-pull](https://docs.ansible.com/ansible/latest/cli/ansible-pull.html). In a typical Ansible setup, you install Ansible on a single **Control Node**, which then runs [Ansible Playbooks](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_intro.html) against **Managed Hosts** to configure them as desired.

However, this approach assumes that Managed Hosts are always online and accessible, which isn’t the case for most homelab workstations (desktops and laptop are often asleep, powered off, or on a different network). This is where ansible-pull excels.

With `ansible-pull`, you install Ansible on each Managed Host. Each host then pulls the latest version of a repository (like this one) and applies the configuration to itself. Combine this with a scheduled job and you can ensure that even intermittently available machines stay up to date with configuration changes.

To get started, install the required packages and run `ansible-pull` as follows:

**Note:** The command below (along with many other things in this repository) has only been tested on Fedora and/or a recent version of an Enterprise Linux distribution (RHEL9+).

```sh
sudo dnf install python3-libdnf5 python3-pip git wget hostname
sudo python3 -m pip install ansible ansible-lint
sudo ansible-pull \
    --limit localhost \
    --directory /opt/homelab-automation \
    --url https://github.com/seantwie03/homelab-automation.git \
    $(hostname --short).yml
```

Notice that the command above installs Ansible via `pip` instead of `dnf`. This is because the ansible package in the Fedora repositories does not include `ansible-pull`. Also, the command above runs `pip` with `sudo`. This is not recommended but `ansible-pull` must be installed system-wide for the persistent systemd-timer that runs as root.

This repo was likely cloned without any authentication because running this playbook is what sets up the password manager. You'll likely want to switch to an authenticated remote. These commands should do it:

```sh
cd /opt/homelab-automation
git remote remove origin
git remote add origin git@github.com:seantwie03/homelab-automation.git
git push --set-upstream origin main
```


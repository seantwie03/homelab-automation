# Workstation Setup

This document is a workstation setup guide.

## Dual Boot

Most workstations I have dual boot Windows and Linux. When dual booting it is recommended to install Windows first. The EFI System Partition created by Windows is only 100MB. This is too small for a long-lived linux system. Follow the disk resizing sections of [this guide](https://sysguides.com/dual-boot-windows-11-and-ubuntu) to create a bigger EFI System Partition and make room for linux.

## Fedora Install

Fedora uses btrfs by default, but it doesn't use many of its features. Follow the latest 'Install Fedora X with Snapshot and Rollback Support' guide from [sysguides](sysguides.com). Following these guides will lead to a more resillient system that is able to recover from problem scenarios.

### Optional Subvolumes

I typically will create the additional subvolumes listed below:

- `/home/$USER/.config/google-chrome`
- `/home/$USER/.ssh`
- `/home/$USER/Downloads`


## Setup

1. Clone this repository onto the workstation machine.
2. Install ansible: `sudo dnf install ansible ansible-lint`
3. Run the workstation playbook `ansible-playbook workstation.yml`
4. Manually sign in to everything
    - Password Manager
    - VPN
    - IDE
    - Browser
    - Websites
    - etc.
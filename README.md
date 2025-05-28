# Homelab

```sh
sudo dnf install python3-pip git
sudo python3 -m pip install ansible
sudo ansible-pull \
    --limit localhost \
    --accept-host-key \
    --directory /opt/homelab-ansible \
    --url https://github.com/seantwie03/homelab-ansible.git \
    $(hostname --short).yml
```
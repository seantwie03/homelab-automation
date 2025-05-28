# Homelab

```sh
sudo dnf install python3-pip git
sudo python3 -m pip install ansible
ansible-pull
ansible-pull \
    --limit localhost \
    --accept-host-key \
    --directory /opt/homelab-ansible \
    --url {{ ansible_repo_url }} \
    $(hostname --short)$.yml
```
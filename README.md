# Homelab

```sh
sudo dnf install python3-pip git wget
sudo python3 -m pip install ansible ansible-lint
sudo ansible-pull \
    --limit localhost \
    --accept-host-key \
    --directory /opt/homelab-automation \
    --url https://github.com/seantwie03/homelab-automation.git \
    $(hostname --short).yml
```
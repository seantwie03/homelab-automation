# Teaching with OBS on Niri

## Overview

This setup routes screen content through OBS rather than relying on Zoom's broken
PipeWire screenshare implementation. OBS captures content via niri's screencasting
features, composites it with a webcam feed, and outputs the result as a PipeWire
virtual camera. Zoom receives this as a "Content from 2nd Camera" share — a proper
fullscreen content share, not a video replacement.

```
niri (ext-screencopy) ──► OBS ──► PipeWire Virtual Camera
                                          │
                          pipewire-v4l2 ◄─┘
                                │
                              Zoom (Content from 2nd Camera)
```

---

## 1. Workflow

### OBS Scenes

Two scenes cover all teaching scenarios. Content switching happens entirely through
niri keybinds — you rarely need to interact with OBS during a lecture.

| Scene | Sources | When to use |
|---|---|---|
| **Face** | Webcam (fullscreen) | Talking directly to students, no content |
| **Lecture** | Dynamic Cast Target (fullscreen) + Webcam (PiP, corner) | All content sharing |

### Niri Features

#### Dynamic Cast Target

The "niri Dynamic Cast Target" is a special screencast stream that OBS subscribes to
once. Its content is controlled live via keybinds during the lecture — no OBS
interaction required.

| Keybind | Action |
|---|---|
| `Mod+Shift+W` | Cast the focused window (slides, terminal, anything) |
| `Mod+Shift+M` | Cast the focused monitor |
| `Mod+Shift+C` | Clear — cast target goes transparent |

Workflow: stay on the **Lecture** scene, focus whatever you want to share, hit
`Mod+Shift+W`. The content in Zoom updates immediately.

#### Fake/Detached Fullscreen

Allows a browser-based slide presentation to enter its fullscreen presentation UI
(no toolbar, no tabs) while remaining a normal window in niri.

- Trigger it with `Mod+Ctrl+Shift+F` after opening your slides
- The browser thinks it is fullscreen → renders the clean presentation view
- You can focus other windows (terminal, notes) without breaking the presentation state
- When you cast it via `Mod+Shift+W`, students see a clean fullscreen presentation

#### Block Out Windows

Window rules silently replace specified windows with solid black rectangles in any
screencast. Configured once, requires no attention during lectures. Add rules for
anything that should never appear on camera: email, a password manager, personal
browser profiles.

---

## 2. Launching the Workflow

These steps are performed before or at the start of each Zoom meeting.

### Before the meeting

1. Open your slide presentation in the browser
2. Enter fake fullscreen: `Mod+Ctrl+Shift+F`
   - The browser enters presentation mode but stays as a niri window
3. Open a terminal for any CLI demonstrations

4. Launch OBS:
   ```bash
   flatpak run com.obsproject.Studio
   ```
   - Confirm the **Lecture** scene is selected
   - Click **Start Virtual Camera**

### Starting the meeting

5. Launch Zoom with the pipewire-v4l2 wrapper:
   ```bash
   zoom-teach
   ```
6. Join your meeting
7. Click **Share Screen → Advanced tab → Content from 2nd Camera**
8. Select **OBS Virtual Camera** → click **Share**

### During the meeting

| Goal | Action |
|---|---|
| Show slides | Focus browser → `Mod+Shift+W` |
| Show terminal | Focus terminal → `Mod+Shift+W` |
| Show face only | Switch OBS to **Face** scene |
| Return to content | Switch OBS to **Lecture** scene |
| Share whole monitor | `Mod+Shift+M` |
| Clear content (blank) | `Mod+Shift+C` |

### Ending the meeting

- Stop the Zoom share, leave the meeting
- In OBS, click **Stop Virtual Camera**

---

## 3. Installation

All tasks assume they run as your normal user. Tasks requiring `become: true` need
sudo privileges.

### 3.1 System packages

```yaml
- name: Install pipewire-v4l2
  become: true
  ansible.builtin.dnf:
    name: pipewire-v4l2
    state: present
```

### 3.2 OBS Studio via Flatpak

```yaml
- name: Add Flathub remote (user)
  community.general.flatpak_remote:
    name: flathub
    state: present
    flatpakrepo_url: https://dl.flathub.org/repo/flathub.flatpakrepo
    method: user

- name: Install OBS Studio
  community.general.flatpak:
    name: com.obsproject.Studio
    state: present
    method: user
```

### 3.3 Zoom wrapper script

Wraps the Zoom launcher with `pipewire-v4l2` preloaded so the OBS virtual camera
is visible to Zoom as a V4L2 device.

```yaml
- name: Install zoom-teach wrapper script
  become: true
  ansible.builtin.copy:
    dest: /usr/local/bin/zoom-teach
    mode: "0755"
    content: |
      #!/bin/bash
      LD_PRELOAD=/usr/lib64/pipewire-0.3/v4l2/libpw-v4l2.so exec /opt/zoom/ZoomLauncher "$@"
```

### 3.4 Desktop entry

Creates a dedicated launcher in your application menu.

```yaml
- name: Create zoom-teach desktop entry
  ansible.builtin.copy:
    dest: "{{ ansible_user_dir }}/.local/share/applications/zoom-teach.desktop"
    mode: "0644"
    content: |
      [Desktop Entry]
      Name=Zoom (Teaching)
      Comment=Zoom with OBS virtual camera support
      Exec=/usr/local/bin/zoom-teach %U
      Icon=Zoom
      Terminal=false
      Type=Application
      Categories=Network;VideoConference;
```

### 3.5 xdg-desktop-portal configuration

In this workflow Zoom no longer uses the portal directly, so we switch back to the
gnome portal. This gives OBS access to the gnome portal's picker and the niri
Dynamic Cast Target.

```yaml
- name: Configure xdg-desktop-portal to use gnome portal
  ansible.builtin.copy:
    dest: "{{ ansible_user_dir }}/.config/xdg-desktop-portal/portals.conf"
    mode: "0644"
    content: |
      [preferred]
      default=gnome;gtk;
```

After applying, restart the portal service:

```bash
systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gnome
```

### 3.6 Niri configuration

#### render-drm-device

Required for the gnome portal to correctly import screencopy buffers from the
Intel GPU.

```yaml
- name: Set niri render-drm-device
  ansible.builtin.blockinfile:
    path: "{{ ansible_user_dir }}/.config/niri/config.kdl"
    marker: "// {mark} ANSIBLE MANAGED - render-drm-device"
    block: |
      debug {
          render-drm-device "/dev/dri/renderD128"
      }
```

#### Keybinds

```yaml
- name: Add teaching keybinds to niri config
  ansible.builtin.blockinfile:
    path: "{{ ansible_user_dir }}/.config/niri/config.kdl"
    marker: "// {mark} ANSIBLE MANAGED - teaching keybinds"
    block: |
      binds {
          Mod+Shift+W { set-dynamic-cast-window; }
          Mod+Shift+M { set-dynamic-cast-monitor; }
          Mod+Shift+C { clear-dynamic-cast-target; }
          Mod+Ctrl+Shift+F { toggle-windowed-fullscreen; }
      }
```

> **Note:** If niri reports a config error about duplicate `binds` blocks, move
> these four binds into your existing `binds { }` section and remove the outer
> `binds { }` wrapper added by this task.

#### Block-out window rules

Adjust `app-id` values to match the applications you want hidden from screencasts.
Run `niri msg windows` to find the `app-id` of any open window.

```yaml
- name: Add screencast block-out window rules to niri config
  ansible.builtin.blockinfile:
    path: "{{ ansible_user_dir }}/.config/niri/config.kdl"
    marker: "// {mark} ANSIBLE MANAGED - screencast block-out rules"
    block: |
      window-rule {
          match app-id="thunderbird"
          block-out-from "screencast"
      }
      window-rule {
          match app-id="org.keepassxc.KeePassXC"
          block-out-from "screencast"
      }
```

### 3.7 OBS scene setup (manual, one-time)

OBS scenes cannot be configured via Ansible. Perform this once after installing OBS.

1. Launch OBS: `flatpak run com.obsproject.Studio`
2. Complete the auto-configuration wizard (or cancel it)

**Create the Face scene:**

3. In the **Scenes** panel, click `+` → name it `Face`
4. In the **Sources** panel, click `+` → **Video Capture Device**
   - Select your webcam
   - Resize the source to fill the canvas

**Create the Lecture scene:**

5. In the **Scenes** panel, click `+` → name it `Lecture`
6. In the **Sources** panel, click `+` → **Screen Capture (PipeWire)**
   - The gnome portal picker appears — select **niri Dynamic Cast Target**
   - Resize the source to fill the canvas
7. Click `+` again → **Video Capture Device** → **Add Existing** → select your webcam
   - Resize it small and drag it to a corner for the PiP overlay

## Notes
A few things I flagged in the document worth knowing:

- portals.conf switches back to gnome — since Zoom is no longer using the portal directly in this workflow, OBS can now use the gnome portal (and therefore see the Dynamic Cast Target). The wlr setting was only needed as a workaround for Zoom's broken screenshare.
- The binds {} note — niri may or may not support multiple binds {} blocks in the same config. If it errors, the workaround is to merge those four keybinds into your existing block.
- niri msg windows — useful for finding the correct app-id values when adding block-out rules for your specific applications.


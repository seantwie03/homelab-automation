# Audio Device Fix — HDMI Output Lost After Crash

## What Happened

After a crash, WirePlumber's state database (`~/.local/state/wireplumber/default-profile`) is empty or missing on restart. WirePlumber then falls back to the highest-priority available profile for the Intel PCH audio card, which is `output:analog-stereo` (priority 6500) instead of `output:hdmi-stereo` (priority 5900). This makes the HDMI sinks disappear from the sink list, breaking audio output through the DELL U2717D monitor and its connected speakers.

## How to Fix

Run these two commands to restore the HDMI sink and set it as default:

```sh
# Switch the card profile to HDMI output (DELL U2717D)
pactl set-card-profile alsa_card.pci-0000_00_1f.3 output:hdmi-stereo

# Set the HDMI sink as the default output
pactl set-default-sink alsa_output.pci-0000_00_1f.3.hdmi-stereo
```

After running these commands WirePlumber writes the selection back to its state DB and audio works normally again until the next crash.

## Verifying

```sh
# Confirm the active card profile is hdmi-stereo
pactl list cards | grep -A2 "alsa_card.pci-0000_00_1f.3" | grep "Active Profile"

# Confirm the HDMI sink exists and is the default (marked with *)
pactl list sinks short
```

## Making It Crash-Proof (Optional)

To enforce the HDMI profile regardless of WirePlumber's state, create a WirePlumber config rule:

```sh
mkdir -p /etc/wireplumber/wireplumber.conf.d
```

Create `/etc/wireplumber/wireplumber.conf.d/50-hdmi-profile.conf`:

```
monitor.alsa.rules = [
  {
    matches = [
      {
        device.name = "alsa_card.pci-0000_00_1f.3"
      }
    ]
    actions = {
      update-props = {
        device.profile = "output:hdmi-stereo"
      }
    }
  }
]
```

Then restart WirePlumber:

```sh
systemctl --user restart wireplumber
```

## Troubleshooting Tips

### List all audio cards and their available profiles

Shows every card PipeWire knows about, all profiles it supports, which are available (detected), and which is currently active. Use this to find card names and profile names for `pactl set-card-profile`.

```sh
pactl list cards
```

Key fields to look for:
- **Name:** the card identifier used in `pactl set-card-profile` (e.g. `alsa_card.pci-0000_00_1f.3`)
- **Profiles:** lists all profiles; `available: yes` means the hardware is detected on that output
- **Active Profile:** what is currently selected

### Find HDMI outputs and which monitor is on each port

```sh
pactl list cards | grep -E "hdmi-output|device.product.name|Active Profile"
```

Each `hdmi-output-N` port shows the connected monitor's name (e.g. `DELL U2717D`) when a display is plugged in. Match the port number to the profile name: `hdmi-output-0` corresponds to `output:hdmi-stereo`, `hdmi-output-1` to `output:hdmi-stereo-extra1`, and so on.

### List all active sinks (outputs)

Shows only the sinks currently exposed by the active card profile. If the expected sink is missing here, the card profile is wrong.

```sh
pactl list sinks short
```

### Check what WirePlumber has saved for default profile and default sink

```sh
cat ~/.local/state/wireplumber/default-profile
cat ~/.local/state/wireplumber/default-nodes
```

If these files are empty after a crash, WirePlumber lost its state and will fall back to profile priority order on next restart.

### Check ALSA's view of hardware (bypasses PipeWire)

Useful to confirm the kernel sees the audio devices even if PipeWire/WirePlumber is confused.

```sh
aplay -l
```

### Switch to a different HDMI output

1. Find the card name and available HDMI profiles:
   ```sh
   pactl list cards | grep -E "Name:|hdmi.*available: yes|Active Profile"
   ```
2. Set the desired profile (replace `extra1` with the correct suffix):
   ```sh
   pactl set-card-profile alsa_card.pci-0000_00_1f.3 output:hdmi-stereo-extra1
   ```
3. Find the new sink name and set it as default:
   ```sh
   pactl list sinks short
   pactl set-default-sink <sink-name>
   ```


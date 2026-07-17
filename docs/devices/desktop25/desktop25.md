# Desktop - Custom Built in 2025

This is a custom desktop computer I built in 2025. It repurposed the case and power supply from my previous build from 2016.

## Usage

This machine is used for teaching, coding, and tinkering.

### Teaching Requirements

When I teach I need the following to all work at the same time:

- Zoom
    - Screen share
    - Camera
    - Microphone
- Virtual Machines
- Custom terminal workflows built around the Kitty terminal
- Browser with several tabs open

## Hardware Information

See the [parts list](./desktop25-parts_list.md) for details.

### Specs

- **Processor**: Intel Core i7-14700K
- **RAM**: 64GB
- **HDD**:
    - 1TB   - Linux
    - 500GB - Windows

## BIOS Updates

The motherboard is a GIGABYTE Z790 EAGLE AX (Rev. 1.x). Download BIOS updates
from the [official support page](https://www.gigabyte.com/Motherboard/Z790-EAGLE-AX-rev-1x/support#support-dl-bios).
Confirm that the motherboard model and revision match before flashing. Prefer
the newest stable release rather than a version whose name ends in a letter,
which indicates a beta release.

Before updating, record any settings that may need to be restored, such as the
boot order, Secure Boot configuration, virtualization settings, fan curves,
and XMP setting. Use reliable power and do not update during a storm or when a
power interruption is likely.

### Required Settings

Set **Advanced Mode > Settings > IO Ports > IOAPIC 24-119 Entries** to
**Disabled**. With this option enabled, the computer does not reliably wake
from suspend. Loading Optimized Defaults during a BIOS update enables it again,
so disable it before booting Linux after every BIOS update or settings reset.

### Update with Q-Flash

1. Download the correct compressed BIOS update from the support page and
   extract it.
2. Format a USB flash drive as FAT32 and copy the extracted BIOS file to it.
   Do not rename the file to `GIGABYTE.bin`; that name is only required for
   Q-Flash Plus.
3. Reboot and press `End` during POST to open Q-Flash. Alternatively, enter BIOS
   Setup with `Delete` and start Q-Flash from there with `F8`.
4. Select **Update BIOS From Drive**, select the USB flash drive, and select the
   extracted BIOS file. Verify that Q-Flash identifies it as an update for the
   Z790 EAGLE AX before continuing.
5. Start the update. Do not turn off or restart the computer, press the reset
   button, or remove the USB drive while the BIOS is being read or written.
6. After the automatic restart, enter BIOS Setup, load **Optimized Defaults**,
   save, and restart again.
7. Re-enter BIOS Setup and restore only the required custom settings. Keep
   Intel default CPU settings and leave XMP disabled initially when diagnosing
   stability problems. Restore the required setting documented above by
   disabling **IOAPIC 24-119 Entries**.
8. After Linux starts, verify the installed version:

   ```sh
   sudo dmidecode -s bios-version
   sudo dmidecode -s bios-release-date
   ```

### Recover with Q-Flash Plus

Use Q-Flash Plus if the computer cannot boot into BIOS Setup. Extract the BIOS
download, rename the BIOS file to `GIGABYTE.bin`, and place it on a FAT32 USB
flash drive. With the computer shut down but the power supply connected and
switched on, insert the drive into the rear USB port labeled **BIOS**, then
press the Q-Flash Plus button. Wait until its flashing indicator stops
completely. Do not interrupt power or remove the USB drive while it is active.

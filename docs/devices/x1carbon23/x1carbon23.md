# Lenovo ThinkPad X1 Carbon 11th Gen (2023)

The Lenovo ThinkPad X1 Carbon (11th Gen) was originally released in April 2023. I purchased this unit on the secondary market in 2026 (see [2026 Laptop Buying Comparison](../2026-laptop-buying.md)) to succeed [x1carbon2018](../x1carbon2018/x1carbon2018.md) as a 32 GB portable Linux workstation.

## Usage

This laptop is used for coding, courseware development, travel, and running multi-VM RHEL `libvirt`/KVM and Podman container labs away from a desktop.

It shares the same 65W USB-C Power Delivery (`20V / 3.25A`) AC adapter used with `x1carbon2018`.

Because this laptop travels outside the home, keep a BIOS supervisor password, Secure Boot, and LUKS full-disk encryption enabled.

## Hardware Information

- **Model Number**: `21HM000SUS` (Type `21HM`)
- **Serial Number**: `PF4EVNHZ`
- **GTIN**: `196804135922`
- **Factory Ship Date**: `2023-07-11`
- **Factory OS**: Windows 11 Pro (English)
- **Machine Name**: `x1carbon23`

### Specs

- **Processor**: Intel Core i7-1365U vPro (10 cores: 2 Performance + 8 Efficient / 12 threads, up to 5.2 GHz P-core / 3.9 GHz E-core, 12 MB cache; 55W burst / 25W sustained)
- **Graphics**: Integrated Intel Iris Xe Graphics (96 EUs)
- **RAM**: 32 GB LPDDR5 (soldered, 8-channel). The installed memory is rated LPDDR5-6400, but PSREF states 32 GB configurations run at 6000 MT/s due to a platform limitation.
- **Storage**: 512 GB M.2 2280 PCIe 4.0 x4 OPAL 2.0 NVMe SSD (Lenovo "G4 Performance"; single M.2 2280 slot, supports up to 2 TB). Lenovo's parts list for this serial includes interchangeable drives from multiple suppliers, including Kioxia (`5SS0V26470`) and WD (`5SS0V26488`), so the installed vendor must be confirmed on the machine.
- **Display**: 14.0" WUXGA (1920x1200) 16:10 Anti-Glare IPS On-Cell Multi-Touch, 400 nits, 100% sRGB, Low-Power, Eyesafe Certified 2.0 (LCD module `5M11H62546`, equivalent `5M11H62550`; BOE panel `5D10V82444` listed in the parts list)
- **Camera**: FHD 1080p + IR Hybrid USB camera with physical privacy shutter (`5C21D67548`)
- **Audio**: Realtek ALC3306 codec, quad Dolby Atmos speakers (2x 2W woofers + 2x 0.8W tweeters), quad-microphone 360° far-field array
- **Wireless**: Intel Wi-Fi 6E AX211 vPro (802.11ax 2x2) + Bluetooth 5.3, integrated on the system board (`5B21L76640`)
- **Input**: 6-row spill-resistant backlit ThinkPad keyboard, TrackPoint, 56 x 110 mm glass 3-button trackpad, and Match-on-Chip power-button fingerprint reader (`5F30V25942` or equivalent `5F30V25943`, the latter listed as Synaptics)
- **Battery**: 57 Wh rechargeable Li-ion battery (`5B10W13973`); supports Rapid Charge (up to 80% in 1 hour while off, in standby, or in hibernation) with a 65W USB-C PD 3.0 adapter
- **Chassis & Weight**: Deep Black carbon-fiber top cover and aluminum bottom cover; `315.6 x 222.5 x 15.36 mm` (`12.43 x 8.76 x 0.60 in`), starting at `2.48 lbs` (`1.12 kg`)
- **Ports**:
    - 2x Thunderbolt 4 / USB4 40 Gbps (Power Delivery 3.0, DisplayPort 1.4a)
    - 2x USB-A 3.2 Gen 1 (5 Gbps; 1x Always On)
    - 1x HDMI 2.1 (up to 4K @ 60 Hz)
    - 1x 3.5 mm headphone / microphone combo jack

Lenovo's parts list includes interchangeable parts from multiple suppliers for several components, such as the SSD, fingerprint reader, touchpad, and LCD module. Part numbers listed with an "equivalent" are not proof of which supplier's part is installed.

### Warranty & Service

- **Status**: Out of warranty (`0` days remaining as of `2026-11-02`); ship-to location United States
- **Lenovo End of Service**: `2029-10-09`
- **Post-Warranty Option**: Lenovo lists the unit as "Extendable", with Premier Onsite Support available for purchase starting November 2026
- **Not Included**: The unit never had Accidental Damage Protection (ADP); Lenovo offers it only as a paid upgrade

Warranty history from Lenovo's warranty lookup for `PF4EVNHZ`:

| Entitlement | ID | Type | Start | End |
| :--- | :--- | :--- | :--- | :--- |
| 3Y Premier Support | `UKN` | On Site | `2023-07-28` | `2026-07-27` |
| 3Y On-site + TICRU | `UDR` | On Site | `2023-07-28` | `2026-07-27` |
| 3Y Depot, 9X5 2BD Warranty | `3EZ` | Depot | `2023-07-28` | `2026-07-27` |
| 1YR Battery (Carry-in/Depot) | `1EZBAT` | Depot | `2023-07-28` | `2024-07-27` |
| 3Y Extended Battery (Sealed Battery Replacement) | `3YSBTY` | | `2023-07-28` | `2026-07-27` |
| 3Y Keep Your Drive | `VRI` | | `2023-07-28` | `2026-07-27` |

Smart Performance, Smart Lock, and Lenovo Identity Advisor show no subscription.

### Links

- [Lenovo PSREF Spec Sheet (PDF)](https://psref.lenovo.com/syspool/Sys/PDF/ThinkPad/ThinkPad_X1_Carbon_Gen_11/ThinkPad_X1_Carbon_Gen_11_Spec.pdf)
- [Lenovo Marketing Site](https://www.lenovo.com/us/en/p/laptops/thinkpad/thinkpadx1/thinkpad-x1-carbon-gen-11-14-inch-intel/len101t0049)
- [Support Site (`PF4EVNHZ`)](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x1-carbon-11th-gen-type-21hm-21hn/21hm/21hm000sus/pf4evnhz)
- [Parts List (`PF4EVNHZ`)](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x1-carbon-11th-gen-type-21hm-21hn/21hm/21hm000sus/pf4evnhz/parts)
- [Warranty Lookup (`PF4EVNHZ`)](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x1-carbon-11th-gen-type-21hm-21hn/21hm/21hm000sus/pf4evnhz/warranty)
- [Lenovo Linux for Personal Systems](https://www.lenovo.com/linux) (Lenovo document `PD031426`)

### Lenovo As-Built Parts List

Retrieved from the Lenovo parts list for serial `PF4EVNHZ` on `2026-11-02`. Where Lenovo lists more than one part for the same component, the entries are interchangeable parts from different suppliers, and the list does not show which one is installed. Substitutes are parts Lenovo may ship as replacements.

| Component | FRU | Lenovo Description | Substitutes / Notes |
| :--- | :--- | :--- | :--- |
| System board | `5B21L76640` | i7-1365U, 32 GB, Windows DPK, AMT, Intel AX211 WLAN | Integrated CPU, RAM, and Wi-Fi |
| LCD module | `5M11H62546` | 14" WUXGA Touch Anti-Glare IPS 400nit 100% sRGB | Alternate supplier: `5M11H62550` |
| LCD panel | `5D10V82444` | BOE 14.0 WUXGA AG | |
| SSD | `5SS0V26470` | 512 GB M.2 2280 PCIe 4.0 x4 OPAL, Kioxia | Equivalent: `5SS0V26488` (WD); substitutes: `5SS0W79570` (Samsung), `5SS1D71705` (UMIS), `5SS1L46685` (Kioxia, non-OPAL) |
| SSD | `5SS0V26488` | 512 GB M.2 2280 PCIe 4.0 x4 OPAL, WD | Equivalent: `5SS0V26470` (Kioxia) |
| Battery | `5B10W13973` | 15.44V 57Wh 4-cell | Equivalent or substitute: `5B10W13974`, `5B10W13975`, `5B11M90056`, `5B11M90057`, `5B11M90058` |
| Camera | `5C21D67548` | Camera, Hybrid, USB, 2MIC, UF, Chicony | USB camera, not MIPI |
| Fingerprint reader | `5F30V25942` | CS21 3.79 MoC Black Slim FOP | Equivalent: `5F30V25943` |
| Fingerprint reader | `5F30V25943` | CS21 3.79 MoC Black Slim FOP, Synaptics - Ofilm | Equivalent: `5F30V25942` |
| Touchpad | `5M11G56137` | CS21 2-button clickpad, glass + Elan PCB, Sunrex | Alternate supplier: `5M11G56136` (Chicony) |
| Touchpad | `5M11G56136` | CS21 2-button clickpad, glass + Elan PCB, Chicony | Alternate supplier: `5M11G56137` (Sunrex) |
| Touchpad cable | `5C10V83233` | FPC, touchpad, Hongyuen | Substitutes: `5C10V83234` (Flexium), `5C10V83235` (Unimicron) |
| Keyboard / C-cover | `5M11H62608` | C-cover with keyboard, US English, black, backlit, fingerprint, WLAN | Substitute: `5M11H62610` |
| Cooling | `5H40W36680` | CPU heatsink with fan, Delta | Substitute: `5H41B77402` |
| Speakers | `5SB1H02539` / `5SB1H02540` | Woofer assembly (Lux / YC) | Alternate suppliers |
| Speakers | `5SB1D97329` / `5SB1D97330` | Tweeter assembly (Lux / YC) | Alternate suppliers |
| Audio jack | `5M21D97366` | Audio jack, Lotes | Substitutes: `5M21D97367`, `5M21K06133` |
| RTC battery | `5B11J02394` | CR2016 coin cell | Substitute: `5B11J02395` |
| AC adapter | `5A10W86303` | 65W USB-C, 2-pin, black | Not included with this purchase; substitute: `5A10W86295` |
| Power cord | `42T5008` | USA/Canada, 1 m, 2-pin | |
| WLAN door | `5CB1J18172` | D-cover for WLAN | |
| SSD thermal | `5B40Z68880` / `5R61C74087` | SSD thermal bracket / SSD thermal rubber | |
| Misc. internal | `5M11J01011`, `5M21C99906`, `5M21C42009` | WLAN/camera cable guide, fingerprint reader bracket, USB connector bracket | |
| Kits & consumables | `5S10Z89222`, `5L11H70963`, `5R61C90386`, `5M21C98290`, `5M21C42015` | Screw kit, label kit, thermal support rubber, clickpad insulation tape, keyboard waterproof Mylar | |
| Recovery media | `5R31N66991` | Windows 11 Pro x64, US | |

## Linux & Firmware Notes

- **Official Linux Certification**: Lenovo's [Linux for Personal Systems](https://www.lenovo.com/linux) page (`PD031426`, last modified `2026-10-20`) lists the X1 Carbon 11th Gen (2023) as certified for RHEL 9.2, Ubuntu 22.04, and Fedora 38. Hardware power profiles (`Fn+L` Power Saver, `Fn+M` Balanced, `Fn+H` Performance) work through `thinkpad_acpi` and `power-profiles-daemon` / `tuned-ppd`.
- **Mainline Kernel Drivers**: CPU frequency scaling (`intel_pstate`), Iris Xe graphics (`i915`), wireless (`iwlwifi` / `btintel`), Sound Open Firmware audio (`sof-audio-pci-intel-tgl`), the USB Hybrid webcam (`uvcvideo`, avoiding the Intel MIPI IPU6 camera option), and `s2idle` (S0ix) standby all use mainline kernel drivers, with no out-of-tree kernel modules needed on `bootc`.
- **Userspace Components**: The fingerprint reader uses `fprintd` / `libfprint`. Mesa provides OpenGL (`iris`) and Vulkan (`anv`). `intel_lpmd` is an optional low-power daemon, not a kernel driver.
- **Hardware Video Decode**: Check which VA-API profiles the stock Fedora driver provides with `vainfo`. Codecs missing from the stock driver require `intel-media-driver` from RPM Fusion (see `Q14` in [immutable/migration/README.md](../../../immutable/migration/README.md#open-questions)).
- **Firmware Updates (`fwupd` / LVFS)**: System UEFI/BIOS and Embedded Controller (EC) updates are delivered through LVFS. Use `fwupdmgr get-devices` to confirm whether Intel Management Engine and SSD firmware are also updateable on this unit.

  ```sh
  fwupdmgr refresh
  fwupdmgr get-updates
  fwupdmgr update
  ```

## Verify on Arrival

Run these checks during the 30-day return window and record the results above:

| Check | Command |
| :--- | :--- |
| SSD vendor and model | `sudo nvme list` |
| Battery capacity vs. 57 Wh design | `upower -i $(upower -e \| grep BAT)` |
| Wi-Fi card | `lspci -nn \| grep -i net` |
| Webcam is USB | `lsusb \| grep -i camera` |
| Display resolution and touch | `kscreen-doctor -o` |
| Firmware devices on LVFS | `fwupdmgr get-devices` |
| VA-API codec support | `vainfo` |
| Fingerprint enrollment | `fprintd-enroll` |

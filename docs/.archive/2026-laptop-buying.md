# 2026 Laptop Buying Comparison

This document compares three secondary-market Lenovo ThinkPad candidates evaluated in 2026 to replace the [ThinkPad X1 Carbon 6th Gen (2018)](./x1carbon2018/x1carbon2018.md) (`20KG022US`: Intel Core i7-8550U 4C/8T, 16 GB RAM, 512 GB NVMe SSD).

## Goals for the System

The 2018 X1 Carbon still handles light travel tasks, but its 4-core/8-thread `i7-8550U` processor and 16 GB of soldered RAM bottleneck modern local virtualization and container workflows. The replacement laptop targets the **$400–$800** used/refurbished business ThinkPad market with the following priorities:

1. **First-Class Linux & Immutable `bootc` Compatibility (Top Priority)**
   - Must run Fedora and this repository's immutable `bootc` workstation image (`workstation-kde` on KDE Plasma Wayland) cleanly using **mainline Linux kernel drivers**.
   - **No out-of-tree kernel modules:** Avoid NVIDIA discrete GPUs and Intel MIPI IPU6 ("Computer Vision") webcams, both of which complicate immutable OS image builds and upgrades.
   - **Windows-free maintenance:** Full UEFI/BIOS, Embedded Controller (EC), and SSD firmware update support through `fwupd` and the Linux Vendor Firmware Service (LVFS).
   - **Reliable mobile basics:** Stable `s2idle` (S0ix) sleep/wake residency, mainline Wi-Fi 6E and Bluetooth drivers, working audio/microphones under PipeWire, and native Wayland fractional scaling.

2. **Ready-to-Use Memory & Storage (No Post-Purchase RAM/SSD Upgrades)**
   - **32 GB+ RAM installed from the seller:** Required to comfortably run a 4-VM RHEL 10 `libvirt`/KVM lab (~12 GB guest RAM allocated across a graphical workstation VM and three server VMs) alongside the host KDE desktop, browser tabs, editor, and Podman containers.
   - **512 GB+ NVMe SSD installed from the seller:** Enough headroom for the host OS, container layers, RHEL installation ISOs, and multi-snapshot `qcow2` VM disk images without immediately swapping drives.
   - **Battery is the only planned future hardware replacement:** All three finalists use soldered LPDDR5/LPDDR5x memory, which is acceptable at 32 GB. Internal batteries are standard screw-mounted ThinkPad packs (not glued), making a future battery refresh straightforward if capacity degrades.

3. **Unplugged Portability & Practical Battery Life**
   - Light enough (~2.5–2.9 lbs) to carry easily in a backpack and use away from power outlets.
   - Strong performance-per-watt for unplugged Slidev/Playwright courseware builds, code editing, and local KVM lab testing, paired with standard **65W USB-C Power Delivery** charging.

---

## Side-by-Side Comparison

For baseline context, the existing **ThinkPad X1 Carbon 6th Gen (`i7-8550U`, 4C/8T)** scores **5,795** Multi-Thread and **2,001** Single-Thread on PassMark, and roughly **2,800–3,200** in sustained Cinebench R23 Multi-Core.

- **Interactive CPU Benchmark Comparison (Baseline + All 3 Candidates):** [PassMark: i7-8550U vs. i7-1365U vs. i7-1370P vs. Ryzen 7 PRO 7840U](https://www.cpubenchmark.net/compare/3064vs5266vs5129vs5319)

| Feature | ThinkPad X1 Carbon Gen 11 | ThinkPad T14s Gen 4 (Intel) | ThinkPad X13 Gen 4 (AMD) |
| :--- | :--- | :--- | :--- |
| **eBay Listing** | [#407324683298](https://www.ebay.com/itm/407324683298) | [#198467254609](https://www.ebay.com/itm/198467254609) | [#366778997492](https://www.ebay.com/itm/366778997492) |
| **Total Price (Shipped)** | **$785.00** (Free shipping) | **$729.99** (Free shipping) | **$772.05** ($749.99 + $22.06, OBO) |
| **Lenovo MTM / Serial** | `21HM000SUS` / `PF4EVNHZ` | `21F7S2GQ00` / `GM0CY5ES` (lot sample) | `21J30009US` / `GM0JMEK0` |
| **Condition** | Pre-Owned (light exterior wear) | Good - Refurbished (C4 grade) | Used ("Super Clean") |
| **65W USB-C Charger** | **Not included** (~$20–$30 extra) | **Included** | **Included** (Genuine Lenovo 65W) |
| **Return Policy** | 30-day returns (buyer pays shipping) | **30-day free returns** | No seller returns (eBay MBG only) |
| **Warranty Coverage** | Expired (`2026-07-27`) | **1-Year Allstate Refurb Warranty** (Lenovo expired `2026-10-25`) | **Lenovo Premier Support Plus + Sealed Battery + ADP to `2028-08-07`** |
| **Processor** | Intel Core i7-1365U vPro (15W) | **Intel Core i7-1370P** (28W P-series) | **AMD Ryzen 7 PRO 7840U** (28W; 15–30W cTDP) |
| **Cores / Threads** | 10C (2P + 8E) / 12T | **14C (6P + 8E) / 20T** | **8 Full Zen 4 Cores / 16T** |
| **Chassis Power Limits (PL2 / PL1)** | 55W burst / **25W sustained** | ~60–64W burst / **~24–28W sustained** | 30W burst / **20W sustained** |
| **PassMark Multi / Single (Chip Avg)** | 13,619 / 3,348 (**2.4x** multi) | 19,716 / 3,463 (**3.4x** multi) | **24,335 / 3,672** (**4.2x** multi) |
| **Geekbench 6 Multi / Single** | ~8,000–8,800 / ~2,200 | **~11,000–12,497 / ~2,639** | **11,130 / 2,508** |
| **Cinebench R23 Multi / Single (1st Run)** | 9,343 / 1,877 | **~11,500–13,500** AC (~10,000 batt) / ~1,900 | **10,576** (AC & batt) / 1,709 |
| **Cinebench R15 30-Run Loop (Avg / Floor)** | **1,275 / 1,096** (~1,173 est. on batt) | **~1,750 / ~1,500** AC | 1,157 / 1,018 (AC & batt, 20W cap) |
| **Integrated GPU (Time Spy Graphics)** | Intel Iris Xe (**1,463** pts) | Intel Iris Xe (**~1,572** pts) | **AMD Radeon 780M** (**2,472** pts, +69%) |
| **Memory** | 32 GB LPDDR5-6000 (soldered) | 32 GB LPDDR5 (soldered) | **32 GB LPDDR5x-6400** (soldered) |
| **Storage (M.2 2280 PCIe 4.0)** | 512 GB OPAL NVMe SSD | 512 GB Kioxia OPAL NVMe SSD | **1 TB Kioxia OPAL NVMe SSD** |
| **Display (16:10 Anti-Glare)** | **14.0" 1920x1200 IPS Touch, 400 nit, 100% sRGB** | 14.0" 1920x1200 IPS Touch, 300 nit, **45% NTSC** | **13.3" 1920x1200 IPS Touch, 300 nit, 100% sRGB** |
| **Webcam** | **1080p FHD+IR USB** (`uvcvideo`, verified) | **5MP RGB+IR USB** (`uvcvideo`, verified on `21F7S2GQ00`) | **5MP RGB+IR USB** (`uvcvideo`, verified) |
| **Wi-Fi / Bluetooth** | Intel Wi-Fi 6E AX211 + BT 5.3 (`iwlwifi`) | Intel Wi-Fi 6E AX211 + BT 5.3 (`iwlwifi`) | Qualcomm NFA725A / WCN6855 Wi-Fi 6E + BT 5.3 (`ath11k_pci`) |
| **Battery & Wi-Fi Runtime (150 nits)** | **57 Wh** (**13h 59m** non-touch NBC; less w/ touch & age) | **57 Wh** (~8h 30m–9h 30m est.) | **41 Wh** (**~7h 35m** touch; 10h 07m w/ 54.7 Wh) |
| **Chassis & Weight** | Carbon fiber + aluminum, **2.48 lbs** | Storm Grey aluminum, **~3.26 lbs** | Storm Grey aluminum, **2.87 lbs** (`1.30 kg` PSREF) |
| **Linux Readiness** | **Excellent** (USB cam verified via BOM) | **Excellent** (USB cam verified via BOM) | **Excellent** (100% mainline kernel) |

---

## Chassis-Specific Benchmark & Efficiency Breakdown

Chip-wide benchmark databases (such as PassMark) pool scores from thick 35W–54W laptops alongside thin subnotebooks. Because we know the exact Machine Type Models, panels, and batteries of all three listings, we can compare standardized laptop measurements from *Notebookcheck*'s reviews of these specific ThinkPad designs (`X1 Carbon G6 20KG`, `X1 Carbon G11 21HN`, `T14s G4 21F6` / `P14s G4 21HF i7-1370P`, and `X13 Gen 4 AMD 21J3`):

| Metric                                           | Baseline: X1C Gen 6 (`i7-8550U`) | X1 Carbon Gen 11 (`i7-1365U`)    | X13 Gen 4 AMD (`R7 PRO 7840U`)              | T14s Gen 4 (`i7-1370P` est.†)     |
|:-------------------------------------------------|:---------------------------------|:---------------------------------|:--------------------------------------------|:----------------------------------|
| **Configured Power (PL2 Burst / PL1 Sustained)** | 29W / 23W                        | 55W / 25W                        | **30W / 20W** (conservative cap)            | ~60–64W / ~24–28W (32.5W in P14s) |
| **PassMark Multi / Single**                      | 5,795 / 2,001                    | 13,619 / 3,348                   | **24,335 / 3,672**                          | 19,716 / 3,463                    |
| **Geekbench 6 Multi / Single**                   | ~3,500 / ~1,150                  | ~8,000–8,800 / ~2,200            | **11,130 / 2,508**                          | **~11,000–12,497 / 2,639**        |
| **Geekbench 5.5 Multi / Single (NBC)**           | ~3,350 / ~950                    | 8,709 / **1,938**                | 9,771 / 1,895                               | **~11,000–11,832** / 1,856        |
| **Cinebench R23 Multi / Single (1st Run)**       | ~3,600 / ~1,030                  | 9,343 / 1,877                        | 10,576 / 1,709                              | **~11,500–13,500** / **1,915**    |
| **Cinebench R15 30-Run Loop (Avg; Start -> Floor)** | ~615; 648 -> ~606             | **1,275**; 1,604 -> **1,096** (-32%) | 1,157; 1,590 -> 1,018 (-36%, 20W cap)       | **~1,750**; ~2,200 -> ~1,500 (-31%) |
| **Unplugged Battery CPU Penalty**                | Minimal                          | **~8% drop** (~1,173 est. CB R15 avg) | **0% drop** (1,157 CB R15 avg)             | **~28% drop** (~10,000 CB R23)    |
| **7-Zip Multi / Single (`MIPS`)**                | ~16,500 / ~3,600                 | 39,077 / **5,941**                   | 34,490 / **5,973**                          | **~50,000–53,407 / 6,176**        |
| **PCMark 10 Overall / Productivity**             | ~3,850 / ~6,100                  | 5,697 / 7,237                        | **6,541 / 9,658**                           | ~6,200–6,500 / ~8,800             |
| **3DMark Time Spy Graphics (iGPU)**              | ~400 (UHD 620)                   | 1,463 (Iris Xe 96EU)                 | **2,472 (Radeon 780M)**                     | ~1,572 (Iris Xe 96EU)             |
| **Power Draw: Idle (Min–Avg)**                   | 3.8 – 8.9 W (WQHD)               | 3.9 – 6.3 W                          | **3.0 – 5.2 W**                             | ~4.2 – 5.5 W (IPS est.)           |
| **Power Draw: Load (Avg / Peak)**                | 47.5 / 52.5 W                    | 41.8 / 63.4 W (25W/55W cap)          | **27.0 / 52.3 W** (20W/30W cap)             | ~45 / 64 W                        |
| **Fan Noise: Idle / Max Load**                   | 28.9 / 35.1 dB(A)                | 24.8 / 42.7 dB(A)                    | **24.6 / 40.9 dB(A)** (26.9 Balanced)       | ~24.2 / 41–45 dB(A)               |
| **Wi-Fi Browsing @ 150 nits (NBC Review)**       | ~10h 01m (when new, FHD)         | **13h 59m** (57 Wh, 400n LP non-touch‡) | **~7h 35m** (41 Wh touch) / **10h 07m** (54.7 Wh) | ~8h 30m–9h 30m (57 Wh, 300n IPS) |

*†Note on `T14s Gen 4 (i7-1370P)`: Notebookcheck tested the `T14s G4` chassis with `i7-1355U` (`50W PL2 / 24W PL1`) and the thicker `P14s G4` chassis with `i7-1370P` (`65W PL2 / 32.5W PL1`, `14,741` CB R23 Multi on AC, `10,000` on battery). In the slimmer `T14s` single-fan chassis, the special-bid `i7-1370P` lands slightly below the `P14s` under sustained AC load.*

*‡Note on `X1 Carbon Gen 11` battery figure: Notebookcheck's `13h 59m` (`10h 31m` at max brightness) was measured on a brand-new unit with the **non-touch** 400-nit Low-Power panel. Listing `PF4EVNHZ` has the **multi-touch** 400-nit Low-Power panel (which draws modestly more power) and ~3.3 years of age (`Jul 2023`, expired battery warranty) compared with ~2.2 years (`Aug 2024`, active battery warranty) on the touch-panel X13 Gen 4.*

### Key Takeaways from Exact-Model Benchmarks

1. **Short Bursts Favor the X13 Gen 4 AMD, While Prolonged Multi-Core Load Favors (or Ties) the X1 Carbon Gen 11:**
   - Lenovo capped the compact 13.3" X13 Gen 4 AMD conservatively at **30W burst / 20W sustained**. On a single Cinebench R23 run (`10,576` vs. `9,343`, **+13%**) and in **short/mixed developer bursts** (`Geekbench 6 Multi`: **11,130** vs. ~8,400; `PCMark 10 Productivity`: **9,658** vs. 7,237) plus **GPU workloads** (`Time Spy Graphics`: **2,472** vs. 1,463, **+69%**), the X13 Gen 4 AMD leads clearly.
   - However, in **prolonged 100% multi-core load** (**30-run Cinebench R15 loop**), the **25W-sustained X1 Carbon Gen 11 (`Ø 1,275`, floor `1,096`) actually outpaces the 20W-capped X13 Gen 4 AMD (`Ø 1,157`, floor `1,018`) by ~10% on AC power**. Once unplugged on battery, applying Notebookcheck's measured **~8% battery-mode reduction** on the X1 Carbon Gen 11 yields an estimated `~1,173` loop average vs. `1,157` (**0% reduction**) on the X13 Gen 4 AMD—making sustained unplugged CPU throughput virtually a tie. The X13's lower wall draw (`27.0W` vs. `41.8W` average load) mainly reflects its stricter `20W` power cap, which also keeps its fan quieter in Balanced mode (`26.9 dB(A)`).
2. **The X1 Carbon Gen 11 (`PF4EVNHZ`) Wins on Battery Cushion, Screen Size, and Weight (`-0.39 lbs`):**
   - Pairing the **57 Wh** battery with Lenovo's **400-nit Low-Power 100% sRGB** display technology gives the X1 Carbon Gen 11 a substantial runtime lead over the X13 Gen 4 AMD's **41 Wh** battery (`~7h 35min`, scaled from Notebookcheck's `10h 07min` on the 54.7 Wh touch unit)—though accounting for `PF4EVNHZ`'s touchscreen digitizer and ~3.3-year battery age narrows the real-world margin below Notebookcheck's brand-new non-touch `13h 59min` figure. In addition, the carbon-fiber/aluminum X1 Carbon (`2.48 lbs`) is **0.39 lbs lighter** than the Storm Grey all-aluminum X13 (`2.87 lbs`).
3. **The T14s Gen 4 (`i7-1370P`) Has the Highest Plugged-In Compute—at the Cost of Weight, Heat, and Screen Gamut:**
   - With 6 P-cores + 8 E-cores (20 threads), it beats both finalists in plugged-in multi-core compiling/rendering (`~11,500–13,500` CB R23; `~50,000+` 7-Zip MIPS), but drops ~28% on battery, weighs **3.26 lbs** in Storm Grey aluminum, and has the narrowest-gamut **45% NTSC** screen.

---

## Candidate 1: Lenovo ThinkPad X1 Carbon Gen 11 (`$785.00`)

- **Listing:** [eBay #407324683298](https://www.ebay.com/itm/407324683298) — Seller `spicketriver_computers` (99.9% positive feedback)
- **Verified Lenovo Identity:** Type `21HM`, MTM `21HM000SUS`, Serial `PF4EVNHZ` (shipped `2023-07-11`)
- **Lenovo Support & As-Built BOM:** [PCSupport Serial Lookup (`PF4EVNHZ`)](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x1-carbon-11th-gen-type-21hm-21hn/21hm/21hm000sus/pf4evnhz)

### Hardware & Listing Notes

- **Verified Factory Parts (`PF4EVNHZ`):**
  - **System Board (`5B21L76640`):** Intel Core i7-1365U vPro + 32 GB soldered **LPDDR5-6000** (32 GB/64 GB boards step down to `6000 MT/s` per PSREF) + soldered Intel Wi-Fi 6E AX211.
  - **Display (`5M11H62546`):** **14.0" WUXGA (1920x1200) Anti-Glare IPS Multi-Touch, 400 nits, 100% sRGB, Low-Power** panel (`Eyesafe Certified 2.0`—Lenovo's standard multi-touch WUXGA panel on Gen 11).
  - **Webcam (`5C21D67548`):** `Camera,Hybrid,USB,2MIC,UF` — confirmed **standard USB FHD + IR camera**, avoiding the problematic Intel MIPI IPU6 camera option offered on other X1 Carbon Gen 11 builds.
  - **Storage & Battery:** 512 GB M.2 2280 PCIe 4.0 x4 OPAL NVMe SSD (`5SS0V26470`) and 57 Wh 4-cell battery (`5B10W13973`, reported as "Normal" health by seller).
- **Buying Considerations:**
  - **No AC adapter included:** Requires an existing 65W USB-C PD charger or budgeting ~$20–$30 for a Lenovo 65W USB-C adapter.
  - **Out of warranty:** Factory 3-year Premier Support and extended battery coverage expired on `2026-07-27`.

### Linux Compatibility (`workstation-kde` / Fedora `bootc`)

- **Linux Certification:** Lenovo officially certified the ThinkPad X1 Carbon Gen 11 for Linux (Fedora and Ubuntu), so ACPI platform profiles (`Fn+L` / `Fn+M` / `Fn+H` via `thinkpad_acpi` and `power-profiles-daemon`) work out of the box.
- **CPU & KVM Virtualization (`intel_pstate`):** Uses Intel's hybrid Raptor Lake-U architecture (2 Performance cores with Hyper-Threading + 8 Efficient cores = 12 threads) configured at **55W short burst / 25W sustained**. Mainline Fedora kernels handle mixed P/E core scheduling cleanly via ITMT asymmetric core priority (`CONFIG_SCHED_MC_PRIO`) alongside `CONFIG_INTEL_HFI_THERMAL`, and `intel_lpmd` lowers idle power. Because Lenovo sustains 25W on AC, its 30-run Cinebench R15 loop average (`1,275`, floor `1,096`) is ~10% ahead of the 20W-capped X13 Gen 4 AMD on AC (and roughly tied unplugged at an estimated `~1,173` after an ~8% battery-mode drop), though pushing 55W bursts on AC spins its twin fans up to `42.7 dB(A)` (`Fn+L` / `Balanced` tames this when unplugged).
- **Graphics (`i915` / `xe`):** Intel Iris Xe Graphics runs natively on mainline kernel drivers and Mesa (`iris` OpenGL / `anv` Vulkan) with zero out-of-tree kernel modules needed on `bootc`. Stock Fedora provides `libva-intel-media-driver` for open codecs (VP9/AV1), while full non-free VA-API codec acceleration uses `intel-media-driver` from RPM Fusion (or Flathub app runtimes; see open question `Q14` in [immutable/migration/README.md](../../immutable/migration/README.md#open-questions)).
- **Webcam (`uvcvideo`):** Because Lenovo's factory BOM for serial `PF4EVNHZ` confirms the **USB Hybrid camera (`5C21D67548`)** rather than the optional MIPI IPU6 Computer Vision camera, video conferencing and browser capture work out of the box with the standard `uvcvideo` kernel module and PipeWire.
- **Wi-Fi, Audio & Sleep:**
  - **Wi-Fi / BT:** Intel AX211 (`iwlwifi` + `btintel`, Wi-Fi 6E + Bluetooth 5.3) is completely mainline and stable.
  - **Audio:** Quad-speaker Dolby Atmos array (`Realtek ALC3306`) + **quad-microphone** 360° far-field array use Intel Sound Open Firmware (`sof-audio-pci-intel-tgl`), supported natively by `alsa-sof-firmware` and PipeWire.
  - **Sleep (`s2idle`):** Supports modern S0ix (`s2idle`) low-power standby cleanly on Linux without legacy S3 sleep hacks.
  - **Firmware & Biometrics:** Full UEFI/EC/ME updates via `fwupdmgr`; Match-on-Chip fingerprint reader (`5F30V25942`) works with `fprintd`.

---

## Candidate 2: Lenovo ThinkPad T14s Gen 4 Intel (`$729.99`)

- **Listing:** [eBay #198467254609](https://www.ebay.com/itm/198467254609) — Seller `sunnking` (`Sunnking Sustainable Solutions`, 99.7% positive feedback, 18 available / 38 sold, seller inventory `SKU: 1167996`)
- **Verified Lenovo Identity (Photographed Fleet Sample):** Type `21F7`, Corporate Special Bid MTM `21F7S2GQ00` (`21F7-S2GQ00`), Serial `GM0CY5ES` (3-year corporate lease `2023-10-26` to `2026-10-25`)
- **Lenovo Warranty & As-Built BOM:** [PCSupport Serial Lookup (`GM0CY5ES`)](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-t-series-laptops/thinkpad-t14s-gen-4-type-21f6-21f7/21f7/21f7s2gq00/gm0cy5es/warranty)

### Hardware & Listing Notes

- **Verified Factory Parts (`21F7S2GQ00` / `GM0CY5ES`):**
  - **System Board (`5B21L59908`):** **Intel Core i7-1370P** (28W P-series: **6 Performance cores + 8 Efficient cores = 14 cores / 20 threads**, 1.90 GHz base / 5.2 GHz turbo—matching the listing's `1.90 GHz` item specific) + **32 GB soldered LPDDR5** + soldered Intel Wi-Fi 6E AX211.
  - **Webcam (`5C21D67578`):** `Camera,5M,RGB+IR,USB,UF,Ccy` — confirmed **5MP RGB + IR USB camera (`uvcvideo`)** with physical privacy shutter (`5M21H89587`), the exact same Linux-friendly Chicony USB module used in the X13 Gen 4 AMD (not an Intel MIPI IPU6 camera).
  - **Display (`5D10V82399` / `5D10V82401`):** **14.0" WUXGA (1920x1200) Anti-Glare On-Cell Touch IPS, 300 nits, 45% NTSC (~62–66% sRGB)**—functional matte touch panel, though noticeably less color-saturated than the **100% sRGB** panels on the X1 Carbon Gen 11 and X13 Gen 4 AMD.
  - **Chassis & Weight (`5CB1L57624`, `5M11L59593`):** **Storm Grey All-Aluminum** top and bottom covers with grey US-English backlit keyboard and Match-on-Chip fingerprint reader (`5F30V26022`). Per Lenovo PSREF, the Storm Grey aluminum T14s Gen 4 starts at **3.26 lbs (1.48 kg)**—about half a pound heavier than the Deep Black carbon-fiber T14s (`2.76 lbs`) and ~0.78 lbs heavier than the X1 Carbon Gen 11.
  - **Storage, Battery & Charger:** 512 GB M.2 2280 PCIe 4.0 x4 OPAL NVMe SSD (`5SS0V26478`, Kioxia), 57 Wh 4-cell battery (`5B10W51874`), and included 65W USB-C charger.
- **Multi-Unit Fleet & Warranty Context:**
  - `SKU: 1167996` is Sunnking's internal refurbisher lot/asset identifier. Although `GM0CY5ES` is one unit from an off-lease corporate batch (`18 available / 38 sold`), the listing's `1.90 GHz` clock and `Gray` chassis match MTM `21F7S2GQ00` across the lot.
  - Lenovo's 3-year Premier Support + 3-year Extended Battery lease ended `2026-10-25` (`0 days remaining`), so post-purchase coverage comes from eBay Refurbished's **30-day seller-paid free returns** and **1-year Allstate refurbished warranty**.

### Linux Compatibility (`workstation-kde` / Fedora `bootc`)

- **Core Platform (`intel_pstate`, `i915`, `iwlwifi`):** Officially Linux-certified by Lenovo with mainline Intel Iris Xe graphics (same Fedora `libva-intel-media-driver` vs. RPM Fusion `intel-media-driver` VA-API split noted under `Q14` in [immutable/migration/README.md](../../immutable/migration/README.md#open-questions)), mainline Intel AX211 Wi-Fi 6E, `sof-audio-pci-intel-tgl` audio, `s2idle` standby, `fprintd` Match-on-Chip fingerprint support, and full LVFS firmware updates via `fwupdmgr`.
- **28W `i7-1370P` Thermal & Unplugged Power Trade-offs:**
  - Having **6 P-cores + 8 E-cores (20 threads)** gives this T14s substantially stronger multi-VM CPU headroom than the 2 P-core `i7-1365U` (`19,716` vs. `13,619` PassMark Multi).
  - However, packing Intel's 28W–64W P-series chip into a slim T14s single-fan chassis means higher heat, louder fan spin under sustained compilation/VM load, and faster unplugged battery drain than either the 15W `i7-1365U` or AMD's 4nm `Ryzen 7 PRO 7840U`. Using KDE's **Balanced** or **Power Saver** ACPI profile (`power-profiles-daemon` / `tuned-ppd`) when unplugged keeps turbo power spikes in check.
- **Webcam (`uvcvideo`):** Factory BOM `21F7S2GQ00` confirms the **5MP RGB+IR USB camera (`5C21D67578`)**, meaning zero Intel MIPI IPU6 headaches on `bootc`. Because Sunnking ships from a multi-unit lot, still run a quick `lsusb` check upon arrival during the 30-day free return window to confirm the shipped serial matches `21F7S2GQ00`.

---

## Candidate 3: Lenovo ThinkPad X13 Gen 4 AMD (`$772.05` OBO)

- **Listing:** [eBay #366778997492](https://www.ebay.com/itm/366778997492) — Seller `photo-el` (99.2% positive feedback)
- **Verified Lenovo Identity:** Type `21J3`, Corporate Special Bid MTM `21J30009US`, Serial `GM0JMEK0` (shipped `2024-08-02`)
- **Lenovo Warranty & As-Built BOM:** [PCSupport Serial Lookup (`GM0JMEK0`)](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x13-gen-4-type-21j3-21j4/21j3/21j30009us/gm0jmek0/warranty)

### Hardware & Listing Notes

- **Verified Factory Parts (`GM0JMEK0` / `21J30009US`):**
  - **System Board (`5B21L75682`):** **AMD Ryzen 7 PRO 7840U** (8 full Zen 4 cores / 16 threads on TSMC 4nm) + integrated **AMD Radeon 780M** GPU + **32 GB soldered LPDDR5x-6400** + onboard **Qualcomm Wi-Fi 6E `NFA725A`** (`QCNFA725` / `WCN6855` + Bluetooth 5.3; Lenovo's `5B21L75682` BOM specifies Qualcomm rather than the alternate MediaTek `RZ616` option).
  - **Storage (`5SS0V26471`):** **1 TB** M.2 2280 PCIe 4.0 x4 OPAL NVMe SSD (Kioxia, 7,000 MB/s)—double the SSD capacity of the two Intel candidates, giving generous room for multiple KVM lab snapshots and container images.
  - **Display (`5D11L87687`):** **13.3" WUXGA (1920x1200) 16:10 Anti-Glare IPS Touch, 300 nits, 100% sRGB** (`IVO R133NW4K R0`)—matte, full-sRGB color accuracy in a slightly more compact footprint than 14" models.
  - **Webcam (`5C21D67578`):** **5MP RGB + IR USB Camera** (`uvcvideo`) with physical privacy shutter.
  - **Chassis, Input & Ports (`5CB1L57797`, `5CB1M21463`):** **Storm Grey All-Aluminum** top and bottom covers rated by Lenovo PSREF at **2.87 lbs / 1.30 kg** starting weight (`0.39 lbs` heavier than the `2.48 lb` X1 Carbon Gen 11; Notebookcheck's `1.25 kg` figure was measured on the lighter Deep Black carbon-fiber/magnesium variant), **95%-scale US-English backlit keyboard** (~1 mm smaller key dimensions than a full-size ThinkPad keyboard, squished right-edge keys, and no dedicated `Insert` key, per [Notebookcheck's X13 Gen 4 AMD review](https://www.notebookcheck.net/Lenovo-ThinkPad-X13-Gen-4-AMD-laptop-review-Compact-Ryzen-machine-with-mediocre-performance.873874.0.html)), Match-on-Chip fingerprint reader, 2x USB4 (40 Gbps, PD + DisplayPort 1.4a), 2x USB-A 3.2 Gen 1, HDMI 2.1, and 3.5mm audio combo jack. Includes genuine Lenovo 65W USB-C charger.
- **Active Factory Warranty Through August 2028:**
  - Serial `GM0JMEK0` carries active **4-Year Lenovo Premier Support Plus (`2024-08-08` to `2028-08-07`)**, including Next-Business-Day On-Site repair, **Accidental Damage Protection (ADP)**, Keep Your Drive, and a **4-Year Sealed Battery Warranty (`SBTY`)** (one free replacement if battery health fails Lenovo's diagnostic threshold before August 2028). Lenovo Smart Lock shows `No Active Subscription`.
  - **Second-Owner Transferability Caveat:** Unlike Dell, Lenovo ties ThinkPad entitlements to the **serial number (`GM0JMEK0`)** in the country of purchase (US), so standard Premier Support hardware repairs and Sealed Battery replacements routinely work for second owners without a formal ownership transfer. However, Lenovo's US *Personal Computing Devices Services Agreement* technically prohibits assigning upgraded service contracts without Lenovo's written consent and original invoice—so treat **ADP** (especially total-loss unit replacements, where case managers may request the original corporate proof of purchase) as a high-value bonus rather than a 100% guaranteed insurance policy.
  - **Battery Capacity:** Ships with Lenovo's smaller **41 Wh** battery option (`5B11H56370`) rather than the optional **54.7 Wh** pack tested in Notebookcheck's review. Scaling Notebookcheck's measured `10h 07min` Wi-Fi browsing test (54.7 Wh battery + identical `IVO R133NW4K R0` 300-nit touch screen) to 41 Wh yields **`~7h 35min`** at 150 nits (**`~6h 24min`** at max brightness); cross-swapping a factory 41 Wh unit to a 54.7 Wh pack has not been verified.
  - **BIOS / Lock Status:** Seller confirmed no BIOS supervisor password and no corporate MDM / Absolute Persistence lock (note: seller does not accept discretionary returns, though eBay's 30-day Money Back Guarantee still covers any mismatch on arrival).

### Real-World CPU & GPU Behavior vs. Intel 13th Gen

Lenovo configured the compact 13.3" X13 Gen 4 AMD conservatively at **30W short burst / 20W sustained** (below the chip's 28W default TDP). As a result, while chip-wide PassMark averages show `24,335`, Notebookcheck's X13 Gen 4 AMD review measured **`10,576`** on a single Cinebench R23 Multi-Core run (**~13% ahead** of the X1 Carbon Gen 11's `9,343`), **`11,130`** in Geekbench 6 Multi-Core (~30% ahead in short bursts), and **`2,472`** in 3DMark Time Spy Graphics (**+69% faster** than Iris Xe). Over a prolonged **30-run Cinebench R15 loop**, however, that `20W` thermal cap drops its sustained AC average to **`1,157` (`1,590 -> 1,018`)**—about **10% behind** the 25W-sustained X1 Carbon Gen 11 (`1,275`, floor `1,096`) on AC, and roughly **even on battery** once the X1 Carbon's ~8% battery-mode reduction (`~1,173` est. vs. `1,157` with 0% drop on the X13) is factored in. Its stricter `20W` ceiling also explains its lower wall power draw (`27.0W` vs. `41.8W` average load) and whisper-quiet Balanced-mode acoustics (`26.9 dB(A)` Balanced / `40.9 dB(A)` Max), while giving `libvirt`/KVM **8 uniform Zen 4 cores (16 threads)**.

### Linux Compatibility (`workstation-kde` / Fedora `bootc`)

- **Linux Certification:** Lenovo officially certifies the ThinkPad X13 Gen 4 AMD for Linux, with full LVFS (`fwupdmgr`) support for system UEFI, EC, and NVMe SSD firmware updates.
- **CPU Power Management (`amd-pstate-epp`):** Uses the mainline `amd-pstate-epp` hardware-guided frequency scaling driver enabled by default on Fedora and RHEL 10. Integrates directly with KDE Plasma's power profile slider (`power-profiles-daemon` / `tuned-ppd`) to drop idle clocks to ~400 MHz on battery while boosting cleanly to 5.1 GHz under load.
- **Graphics (`amdgpu` + Mesa `radeonsi`/`radv`):**
  - The **AMD Radeon 780M** is integrated directly onto the Ryzen 7 PRO 7840U processor die (not a separate discrete GPU chip with hybrid switchable-graphics power drain).
  - Runs on the mainline `amdgpu` kernel driver and Mesa `radeonsi`/`radv` with zero out-of-tree kernel modules needed on `bootc` and smooth KDE Wayland compositing. Stock Fedora's `mesa-va-drivers` provides hardware VA-API acceleration for open codecs (VP9 and AV1 encode/decode), while patent-encumbered H.264/HEVC hardware acceleration requires `mesa-va-drivers-freeworld` from RPM Fusion (or Flathub app runtimes; see open question `Q14` in [immutable/migration/README.md](../../immutable/migration/README.md#open-questions)).
  - **BIOS Tip for VM Host Memory:** In UEFI setup (`Config -> Display -> UMA Frame Buffer Size`), keep the iGPU memory allocation set to **`Auto`** (512 MB carve-out) rather than manually reserving 4 GB or 8 GB. Under Linux, `amdgpu` dynamically shares system RAM whenever graphics workloads need more memory, while `Auto` leaves ~31.5 GB available to the kernel and `libvirt` VMs.
- **Webcam (`uvcvideo`):** AMD ThinkPads never use Intel MIPI IPU6 cameras. Factory part `5C21D67578` is a standard USB 5MP + IR camera driven natively by `uvcvideo`.
- **Wi-Fi, Bluetooth & `s2idle` Sleep (`ath11k_pci`):**
  - Onboard **Qualcomm Wi-Fi 6E `NFA725A`** (`QCNFA725` / `WCN6855`) + Bluetooth 5.3 runs out of the box via the mainline `ath11k_pci` + `btusb` kernel modules and standard `linux-firmware` (`ath11k/WCN6855/hw2.1`; still worth verifying via `lspci` on arrival since non-Qualcomm X13 builds can ship with MediaTek `RZ616`).
  - Early 2023 Linux 6.1–6.4 kernels had occasional `ath11k` `s2idle` resume bugs on AMD 7040 laptops, which were resolved upstream across Linux 6.7+ and Lenovo's 2024+ UEFI updates. On current Fedora `bootc` kernels, `s2idle` suspend/resume and Wi-Fi reconnect work reliably out of the box (simply run `fwupdmgr update` after installation so the latest UEFI/EC firmware is active).
- **Audio, Touchscreen & Biometrics:**
  - Stereo speakers and the 3.5mm combo jack use mainline HD Audio (`snd_hda_intel` with `Realtek ALC3287`), while the dual-array digital microphones use AMD's Phoenix Audio Co-Processor driver (`snd_pci_ps`, ACP 6.3) under PipeWire.
  - Matte 100% sRGB touchscreen uses standard `i2c_hid_acpi` (native in KDE Wayland; touch input can also be disabled in KDE System Settings if desired).
  - Match-on-Chip fingerprint sensor is supported by `libfprint` / `fprintd`.

---

## Summary Recommendation

1. **Best All-Around Ergonomics, Battery & Sustained CPU — [ThinkPad X1 Carbon Gen 11 (`$785.00`)](https://www.ebay.com/itm/407324683298):** `0.39 lbs` lighter (**2.48 lbs** vs. `2.87 lbs`), larger **14.0" 400-nit Low-Power 100% sRGB** touch screen with a full-size keyboard, substantially longer **57 Wh** battery runtime, a **30-day seller return policy**, verified **Linux-safe USB webcam (`uvcvideo`)**, and **~10% faster sustained AC multi-core throughput** (`Ø 1,275` vs. `1,157` in the 30-run Cinebench R15 loop; roughly tied unplugged at `~1,173` est.). Main trade-offs are a smaller `512 GB` SSD, no included charger (~$20–$30 extra), and an expired warranty.
2. **Best Warranty Coverage, 1 TB Storage & Burst/GPU Headroom — [ThinkPad X13 Gen 4 AMD (`$772.05` OBO)](https://www.ebay.com/itm/366778997492):** Seller confirmed an unlocked BIOS with no MDM/Absolute lock. Offers a newer August 2024 build date, **1 TB PCIe 4.0 SSD**, included 65W charger, **active Lenovo Premier Support Plus + Sealed Battery (+ bonus ADP) through August 2028**, stronger short-burst CPU speed (`11,130` Geekbench 6), `+69%` faster integrated graphics (`Radeon 780M`), and quiet Balanced-mode fan acoustics (`26.9 dB(A)`). Main trade-offs are its `20W` sustained power cap (~10% behind the X1C on prolonged AC loops), smaller `13.3"` screen and 95%-scale keyboard, heavier `2.87 lb` aluminum body, `41 Wh` battery, and no discretionary seller returns.
3. **Best Return Policy & 14-Core AC Compute Fallback — [ThinkPad T14s Gen 4 Intel (`$729.99`)](https://www.ebay.com/itm/198467254609):** Lowest shipped cost with charger included, **30-day free returns**, **1-year Allstate warranty**, a **14-core / 20-thread `i7-1370P`**, and a **verified 5MP USB webcam (`5C21D67578`)** on MTM `21F7S2GQ00`. Its trade-offs are a heavier **3.26 lb** Storm Grey aluminum chassis, a basic **45% NTSC** screen, and ~28% unplugged CPU throttling alongside higher heat/power draw from Intel's 28W P-series chip.

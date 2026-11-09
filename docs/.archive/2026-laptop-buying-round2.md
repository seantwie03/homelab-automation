# 2026 Laptop Buying Comparison — Round 2

This document records the second-round replacement search conducted on `2026-11-08` after the Round 1 selection in [2026 Laptop Buying Comparison](./2026-laptop-buying.md) (ThinkPad X1 Carbon Gen 11 [eBay #407324683298](https://www.ebay.com/itm/407324683298), `21HM000SUS`, serial `PF4EVNHZ`, `$785.00`; also documented in [x1carbon23.md](./docs/devices/x1carbon23/x1carbon23.md)) arrived with a dead battery and was returned for a refund.

## Market Status Since Round 1 (`2026-11-08`)

- **Round 1 Alternate — X13 Gen 4 AMD ([eBay #366778997492](https://www.ebay.com/itm/366778997492), `$772.05`, `GM0JMEK0`):** **Sold / Out of Stock**.
- **Round 1 Alternate — T14s Gen 4 Intel ([eBay #198467254609](https://www.ebay.com/itm/198467254609), `$729.99`, Sunnking `21F7S2GQ00`):** **Still in stock**.
- **Lenovo US Outlet:** `0` ThinkPads with `32 GB` RAM in stock.
- **Reebelo US:** `0` ThinkPad X1 Carbon Gen 11/12 or `T14s` Gen 4+ `32 GB` listings in stock.
- **Back Market US & ItsWorthMore Direct:** Back Market blocked automated Playwright access (Cloudflare Turnstile `403`); `itsworthmore.com` is buyback-only while its refurbished inventory sells on eBay.

## Updated Selection Criteria

All Round 1 Linux and `bootc` priorities still apply (`32 GB+` RAM, mainline kernel drivers without out-of-tree modules, `65W` USB-C PD charger compatibility, and `fwupd`/LVFS support). After receiving a dead battery on `#407324683298`, Round 2 weights two safeguards much more heavily:

1. **Return & Battery Protection:** Prefer **30-day seller-paid free returns**, explicit battery-health disclosures (`>= 80%`), or refurbisher warranty coverage over private `"no returns"` listings.
2. **Immediate Arrival Checks (`uvcvideo` & Battery):** Because non-`21HM000SUS` X1 Carbon Gen 11 and Intel `T14s` Gen 4 listings without a disclosed MTM can ship with an Intel MIPI IPU6 camera instead of a USB camera, run `lsusb | grep -i camera` and `upower -i $(upower -e | grep BAT)` immediately during the return window.

---

## Shortlist Overview (`2026-11-08`)

- **[#336864694235](https://www.ebay.com/itm/336864694235) — X1 Carbon Gen 11 (`i7-1365U`, `32 GB / 512 GB`, `$799.99 OBO` shipped):** 30-day seller-paid free returns, `Battery 80% or higher` stated, touchscreen (`400-nit` `100% sRGB`), non-OEM charger.
- **[#287635961464](https://www.ebay.com/itm/287635961464) — X1 Carbon Gen 11 (`i7-1365U`, `32 GB / 512 GB`, `$809.99` shipped):** 30-day seller-paid free returns, 12-month `ItsWorthMore` warranty, actual photos, charger included, severe sticker shadow and screen wear.
- **[#287711626450](https://www.ebay.com/itm/287711626450) — X1 Carbon Gen 11 (`i7-1370P`, `32 GB / 512 GB`, `$824.12` shipped):** 30-day seller-paid free returns, `Very Good - Refurbished`, 1-year warranty, genuine charger, hotter `28W` P-series CPU.
- **[#137465209524](https://www.ebay.com/itm/137465209524) — T14s Gen 4 (`21F7S0CM00` / `GM0FZDBC`, `i7-1365U`, `32 GB / 512 GB`, `$589.00 OBO + $21.90`):** **Verified As-Built BOM** (`400-nit` Low-Power `100% sRGB` non-touch IPS, `5MP RGB+IR USB` `uvcvideo` camera, Deep Black `~2.76 lbs` CFRP chassis, active Lenovo Premier On-Site Support until `2027-02-07`), 30-day seller-paid free returns, 90-day seller warranty, charger included.
- **[#336880415085](https://www.ebay.com/itm/336880415085) — T14s Gen 4 (`i7-1370P`, `32 GB / 512 GB`, `$550.00 + $16.00`):** 14-day buyer-paid returns, `92%` battery / `127` cycles disclosed, `45% NTSC` touch, charger included.
- **[#920085795128](https://www.ebay.com/itm/920085795128) — T14s Gen 4 (`i7-1370P`, `32 GB / 512 GB`, `$590.00` shipped):** No seller returns, `21F7S2GQ00` (`5MP USB` camera BOM, `45% NTSC` touch), Lenovo Premier Support until Dec 2027, no charger.
- **[#198467254609](https://www.ebay.com/itm/198467254609) — T14s Gen 4 (`i7-1370P`, `32 GB / 512 GB`, `$729.99` shipped):** 30-day seller-paid free returns, `21F7S2GQ00` (`5MP USB` camera BOM), 1-year Allstate warranty, charger included.
- **[#287706600155](https://www.ebay.com/itm/287706600155) — T14s Gen 4 AMD (`7840U`, `32 GB / 256 GB`, `$939.99` shipped):** 30-day seller-paid free returns, 12-month `ItsWorthMore` warranty, charger included, high price for `256 GB` and `Good` grade.

---

## Group A: Direct Replacement ThinkPad X1 Carbon Gen 11 (`32 GB`)

### Viable In-Stock Candidates

1. **[eBay #336864694235](https://www.ebay.com/itm/336864694235) — `$799.99 OBO` (Free shipping)** — *Best Battery Guarantee + Free Returns*
   - **Seller & Terms:** `Angies GreenGo Surplus` (`38,274` feedback), **30-day seller-paid free returns**, explicit `"30 days to fully test it"`, Best Offer enabled.
   - **Hardware:** `i7-1365U` (`15W`), `32 GB` LPDDR5, `512 GB` NVMe SSD, `14" 1920x1200` IPS touchscreen (`400-nit` Low-Power `100% sRGB` on X1C11 Touch per PSREF), non-original USB-C charger included.
   - **Battery:** Explicitly discloses **`"Battery 80% or higher"`**.
   - **Trade-offs & Arrival Checks:** Multi-unit lot (`may receive either or`) disclosing front/back cover scratches, keyboard imprint on screen, and screen scratches. No MTM is stated, so verify USB (`uvcvideo`) vs. MIPI IPU6 camera immediately on arrival.

2. **[eBay #287635961464](https://www.ebay.com/itm/287635961464) — `$809.99` (Free 2–4 day shipping)** — *Best Refurbisher Warranty + Actual Photos*
   - **Seller & Terms:** `ItsWorthMore` (`190,431` feedback), `Good - Refurbished`, **30-day seller-paid free returns**, **12-month limited warranty**. *(Note: The same seller also lists [#298330029353](https://www.ebay.com/itm/298330029353) at **`$849.99`** with charger included and example photos rather than actual unit photos.)*
   - **Hardware:** `i7-1365U` (`15W`), `32 GB` RAM, `512 GB` SSD, `14" 1920x1200` IPS touchscreen, charger included (`Laptop`, `Charger`).
   - **Battery & Condition:** `"Battery is in normal working condition"`. Uses actual photos and discloses moderate screen scratches, light keyboard imprint, paint wear, and `"severe wear in the form of sticker shadow"`.
   - **Arrival Checks:** No MTM is listed—confirm USB vs. MIPI camera (`lsusb`) and battery capacity (`upower`) within the 30-day window.

3. **[eBay #287711626450](https://www.ebay.com/itm/287711626450) — `$824.12` (Free 2–4 day shipping)** — *Cleanest Grade (`Very Good - Refurbished`)*
   - **Seller & Terms:** `Highland Performance Systems` (`16,039` feedback), `Very Good - Refurbished`, **30-day seller-paid free returns**, **1-year limited warranty**.
   - **Hardware:** **`i7-1370P`** (`28W` `14C/20T`), `32 GB` RAM, `512 GB` SSD, `14" 1920x1200`, Cellular/WWAN, authentic Lenovo adapter included.
   - **Trade-offs & Arrival Checks:** Cleanest physical grade with warranty and genuine charger, but the `28W` `i7-1370P` runs hotter/louder and trims unplugged battery runtime compared with `i7-1365U` in the thin X1 Carbon chassis. Stock photos with no MTM disclosed—confirm USB vs. MIPI camera and battery wear on arrival.

### Checked & Flagged / Ruled Out (X1 Carbon Gen 11 & Gen 12)

- **[eBay #168793462062](https://www.ebay.com/itm/168793462062) (`$890.00 + $18.85`):** **MTM mismatch + no seller returns.** Seller description says `"Barely new, less than a month of usage"`, original 65W charger, and `21HM000SUS` (`i7-1365U / 32 GB / 512 GB` Touch), but eBay Item Specifics list `MPN: 21HM000GUS`, which Lenovo PSREF resolves to **`i5-1335U / 16 GB / 256 GB`** non-touch. Do not purchase without photo proof of the bottom MTM label and BIOS screen.
- **[eBay #800890895540](https://www.ebay.com/itm/800890895540) (`$899.99 OBO`, Free shipping):** Lightly used `i7-1365U / 32 GB / 1 TB` Touch with 65W charger (`suw_18852`, `17` feedback), but **no seller returns** and no MTM or battery health disclosed.
- **[eBay #206632581303](https://www.ebay.com/itm/206632581303) (`$740.00 + $9.50`):** Contradictory storage (`256 GB` title vs. `512 GB` Item Specifics), omits CPU model, MTM, charger, and battery percentage, and **no seller returns**.
- **Ruled out for defects, panel type, keyboard, or stock:** `#366785586976` (`$819.99`, small dead pixel), `#287658668546` (`$799.99`, white LCD spot + severe sticker shadow), `#178360993396` (`$775 + $29.99`, Privacy Guard panel + underside paint wear), `#880085001815` (`$864.99`, `2880x1800` OLED non-touch), `#188915265782` (`$850 + $8.18`, explicitly states no keyboard backlight), `#147664918553` (`$769.99`, Azure AD / Intune locked), `#287671748879` (`$729.99`, cracked frame + white spots + vibrating speaker), `#189032018902` (`$629.99`, broken primary USB-C charging port), `#900071549092` (`$720.74`, screen issue), and `omahablue` listings (`#900066145052`, `#900047502334` out of stock). X1 Carbon Gen 12 `32 GB` US BIN listings start at `$1,039.99–$1,049.99` (`#298680822703`, `#137880371128`, `#227601890402`).

---

## Group B: Value Intel `ThinkPad T14s Gen 4` Fallbacks (`32 GB`)

Compared with the X1 Carbon Gen 11, the Intel `T14s Gen 4` retains Intel Wi-Fi 6E AX211 (`iwlwifi`), a `57 Wh` battery, and `65W` USB-C PD compatibility, but uses a glass-like Mylar touchpad rather than glass, and `T14s Gen 4` touchscreens are **300-nit `45% NTSC`** instead of `400-nit 100% sRGB`. Deep Black models use a carbon-fiber top (`~2.76 lbs`), whereas Storm Grey all-aluminum models start at `~3.26 lbs`.

1. **[eBay #137465209524](https://www.ebay.com/itm/137465209524) — `$589.00 OBO + $21.90` (`$610.90`)** (`iBankonIT`, `3,185` feedback) — *Verified Unicorn As-Built BOM (`21F7S0CM00` / `GM0FZDBC`)*
   - **Model & Serial:** MTM **`21F7S0CM00`**, Serial **`GM0FZDBC`** (UPC `197528923512`, factory ship date `2024-01-12`).
   - **Warranty & Return Protection:** Active **Lenovo 3-Year Premier Support + 3-Year On-Site 9x5 Repair until `2027-02-07`** (warranty start `2024-02-08`; the 1-year factory battery warranty expired `2025-02-07`), plus **30-day seller-paid free returns** and a **90-day seller warranty**.
   - **Verified Lenovo Factory As-Built BOM (`pcsupport.lenovo.com`) & Linux Compatibility:**
     - **System Board (`5B21L59892`):** Intel Core **`i7-1365U` vPro** (`15W`, `10C/12T` — `2P + 8E`), soldered **32 GB LPDDR5-6400** (running at `4800 MT/s` platform max), Intel Iris Xe Graphics (`i915`/`xe`).
     - **Display (`5D10V82364` / barcode `8SSD10Q67044A4AS39J41DF`):** **`14.0" WUXGA (1920x1200) IPS, 400-nit Low Power, 100% sRGB, Anti-Glare, Non-Touch`** (`AUO 14.0 WUXGA AG`, 30-pin eDP cable `5C11H81432`). Unlike typical off-lease `300-nit 45% NTSC` fleet builds, this unit has the upgraded `400-nit 100% sRGB` low-power matte panel, which significantly reduces backlight power draw under Linux.
     - **Webcam (`5C21D67581` / `5C21D67578`, barcode `8SSC21D67481A1ZJ3A4C50S`):** **`Camera, 5M, RGB+IR, USB, UF`** (AVC/Chicony) with physical privacy shutter (`5M21H89587`) and dual-array microphones (`5R61A19626`). **Confirmed standard USB (`uvcvideo`) webcam** — avoids Intel MIPI IPU6 completely and works out-of-the-box on Fedora/RHEL (with IR camera support for `howdy` if desired).
     - **Wi-Fi / Bluetooth:** **Intel Wi-Fi 6E `AX211` 2x2 AX vPro + Bluetooth 5.3** (`iwlwifi` in-tree kernel driver).
     - **WWAN Cellular (`5W10V25828`, barcode `8SSW11A40420J1BY3CR07E3`):** Factory-installed **`Fibocom L860-GL-16` 4G LTE Cat 16** PCIe modem with WWAN antennas (`5A30Z88202`) and Nano-SIM tray (`5M21H89594`). Driven by the mainline `iosm` kernel driver + `ModemManager` (requires FCC unlock for active cellular use); if unused, disable Wireless WAN in BIOS (`Security -> I/O Port Access -> Wireless WAN -> Disabled`) to eliminate idle PCIe power draw and `ModemManager` log noise.
     - **Storage (`5SS1F20644`, barcode `8SSSS1F20344K1CC3B708ZA`):** **512 GB SK Hynix PCIe 4.0 x4 NVMe M.2 2280 OPAL 2.0 SSD** (`G4 Perf`; `5SS0V26470` Kioxia listed as alternate). Standard replaceable M.2 2280 slot.
     - **Chassis, Input & Biometrics:** **Deep Black** ultralight chassis (`~2.76 lbs / 1.25 kg`) with carbon-fiber hybrid top cover (`5CB1L57654`, `C24`) and black aluminum/magnesium base (`5CB1L57627`), **Chicony backlit US English keyboard** (`5M11L59461`, `BL KB BK WW ENG CHY`), Synaptics glass-like Mylar clickpad (`5M11G56184`), and **Match-on-Chip (`MoC`) fingerprint reader** in the power button (`5F30V25938`, supported out-of-the-box by `fprintd` / `libfprint`).
     - **Battery & Power (`5B11M90033`, barcode `8SSB11M89834B1SH3AM05F9`):** 4-cell **`57 Wh` (`15.36V`) BYD Li-Ion** internal battery (`5B10W51874` LGES listed as alternate) and `65W` USB-C PD AC adapter (`5A10W86318`).
   - **Remaining Arrival Check:** Because the seller states *"Battery health is not guaranteed"* and the 1-year factory battery coverage ended on `2025-02-07` (though the machine only shipped in January 2024), check `upower -i /org/freedesktop/UPower/devices/battery_BAT0` immediately upon delivery within the 30-day free return window.

2. **[eBay #336880415085](https://www.ebay.com/itm/336880415085) — `$550.00 + $16.00` (`$566.00`)** (`freaknightproductions`, `549` feedback)
   - **Specs & Terms:** `i7-1370P` (`28W`), `32 GB`, `512 GB` SSD, `14" WUXGA` IPS touchscreen (`45% NTSC`), Fibocom L860-GL WWAN, `65W` power adapter, **14-day buyer-paid returns**.
   - **Battery:** Explicitly discloses **`Battery = 92%`** and **`Cycle count = 127`**.

3. **[eBay #920085795128](https://www.ebay.com/itm/920085795128) — `$590.00` (Free 2–4 day shipping)** (`specialelectronicscompany`, `133` feedback)
   - **Specs & Terms:** Open-box shape, `MPN: 21F7S2GQ00` (Storm Grey `i7-1370P`, `32 GB`, `512 GB`, `45% NTSC` touch + verified `5MP USB` camera BOM), active **Lenovo Premier Support until December 2027**, **no charger**, **no seller returns**. *(Note: Seller text says `"sRGB touchscreen"`, though `21F7` touch panels per Lenovo PSREF are 300-nit `45% NTSC`.)*

4. **[eBay #198467254609](https://www.ebay.com/itm/198467254609) — `$729.99` (Free shipping)** (`Sunnking Sustainable Solutions`)
   - Round 1 carryover (`21F7S2GQ00`, verified `5MP USB` camera, `i7-1370P`, `32 GB / 512 GB`, charger included, **30-day seller-paid free returns**, **1-year Allstate warranty**).

5. **[eBay #206638684578](https://www.ebay.com/itm/206638684578) — `$399.99` (Free shipping)** (`Sunnking Sustainable Solutions`)
   - Budget fair-grade fallback (`i7-1370P`, `32 GB`, `256 GB` NVMe, Gray, charger included, **30-day seller-paid free returns**), disclosing **dented case and scratched top case** (`C3-Used Fair`, `F6-Fully Functional`).

---

## Group C: AMD `Ryzen 7 PRO 7840U` (`32 GB`) Market Check

With `#366778997492` (`X13 Gen 4 AMD`) sold out, remaining sub-$1,000 `7840U / 32 GB` US eBay inventory is limited and mostly compromised:

- **[eBay #287706600155](https://www.ebay.com/itm/287706600155) — `T14s Gen 4 AMD` (`$939.99`, Good - Refurbished, `ItsWorthMore`):** Only clean `T14s Gen 4 AMD 32 GB` listing available (`7840U`, `256 GB` SSD, Black, charger included, **30-day seller-paid returns**, **12-month limited warranty**, moderate screen scratches, example photos). Expensive for `256 GB` storage, `Good` cosmetics, and Qualcomm Wi-Fi (`ath11k_pci`).
- **Checked & Flagged / Avoided `7840U` Listings:**
  - **[eBay #287701262021](https://www.ebay.com/itm/287701262021) (`P14s Gen 4 AMD`, `32 GB / 1 TB`, `$899.99`, `ItsWorthMore`):** Explicitly discloses **`"keyboard is bulging outward"`** (swollen-battery hazard) plus severe sticker shadow.
  - **[eBay #168838525303](https://www.ebay.com/itm/168838525303) (`$799.00 + $10.21`):** Title says `T14s Gen 4`, but MPN (`THINKPAD T14 GEN 4`) and description both specify **`T14 Gen 4`** (`90%` battery, grade B with keyboard imprints, touch `45% NTSC`, no returns).
  - **[eBay #880086908019](https://www.ebay.com/itm/880086908019) (`T14 Gen 4 AMD`, `32 GB / 512 GB`, `$700.00 OBO + $8.63`):** Gently used with adapter, **no seller returns**, battery health and panel option unspecified.
  - **[eBay #198775877690](https://www.ebay.com/itm/198775877690) (`T14 Gen 4 AMD`, `32 GB / 256 GB`, `$590.00 OBO + $8.20`):** Screen marks, **one broken piece on the front bezel**, **no seller returns**.
- **Side Note (`T14s Gen 6`):** [eBay #960166085351](https://www.ebay.com/itm/960166085351) (`$975.00 OBO + $7.24`) offers a `Ryzen AI 5 PRO 340` (`6C/12T`), `32 GB / 512 GB`, `14" Touch`, charger, and **no returns**; higher price and lower core count than `7840U` plus potential Wi-Fi 7 Linux driver considerations.

---

## Recommendation & Final Selection

1. **Selected & Purchased (`2026-11-08`):** **[#137465209524](https://www.ebay.com/itm/137465209524) (`ThinkPad T14s Gen 4`, `21F7S0CM00` / `GM0FZDBC`, documented in [t14s24.md](./docs/devices/t14s24/t14s24.md))** is the standout configuration in Round 2 once its factory As-Built BOM is decoded: it pairs the cool `15W` `i7-1365U` and `32 GB` LPDDR5 with the **upgraded `400-nit` Low-Power `100% sRGB` anti-glare non-touch IPS panel** (`5D10V82364`), **confirmed `5MP RGB+IR USB` (`uvcvideo`) webcam** (`5C21D67581`), **Deep Black `~2.76 lbs` carbon-fiber top chassis**, Chicony backlit keyboard, Intel `AX211` (`iwlwifi`), **active Lenovo Premier On-Site Support through `2027-02-07`**, and **30-day seller-paid free returns** (only requiring an arrival `upower` check on battery health).
2. **Direct X1 Carbon Gen 11 Replacements (`$799.99–$809.99`):** **[#336864694235](https://www.ebay.com/itm/336864694235) (`$799.99 OBO`, `80%+` battery guaranteed, 30-day free returns)** or **[#287635961464](https://www.ebay.com/itm/287635961464) (`$809.99`, 12-month warranty, actual photos, 30-day free returns)**. Both preserve the X1 Carbon Gen 11's `2.48 lb` chassis, `400-nit` `100% sRGB` touchscreen, glass trackpad, and `iwlwifi` stability, though neither has a pre-verified MTM/serial so `lsusb | grep -i camera` (`uvcvideo` vs. MIPI IPU6) must be checked on arrival.

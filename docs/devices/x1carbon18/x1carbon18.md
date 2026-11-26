# Lenovo Thinkpad X1Carbon 6th Gen (2018)

The Lenovo Thinkpad X1 Carbon (6th Gen) was originally released in 2018.

## Usage

This 6th Gen X1 Carbon was originally used as my main workstation until 2022 when the i7-8550U processor started showing its age.

Now it is mostly used when I want something slightly more powerful/functional than a tablet. For example, when going on a trip I will bring my tablet unless I think I will have time for coding, then I'll bring my X1 Carbon instead.

I'll also use the X1 Carbon to test out new distros or workflows. It is not my daily driver, so it is easier to experiment risk-free.

Since the X1 Carbon is a laptop, it sometimes gets taken with me when I travel. I should consider extra precautions like, setting a BIOS password, enabling Secure Boot, and using Full Disk Encryption.

## Hardware Information

- **Model Number**: 20KG0022US
- **Machine Name**: x1carbon18


### Specs

- **Processor**: Intel i7-8550U
- **RAM**: 16GB
- **HDD**: 512GB NVMe, `/dev/disk/by-id/nvme-LENSE30512GMSP34MEAT3TA_1207865800766`
- **GPU**: Intel UHD Graphics 620
- **Wi-Fi**: Intel Wireless 8265
- **TPM**: TPM 2.0 (Infineon)
- **Fingerprint reader**: Synaptics `06cb:009a`

### Linux Support

- The fingerprint reader works for the BIOS but not in Linux: Fedora's libfprint has no driver for it.
- Fedora's own VA-API driver decodes MPEG-2, JPEG, VP8, and VP9 in hardware. H.264, HEVC, and VC-1 need RPM Fusion's `intel-media-driver`.
- Suspend uses S3 (`deep`) sleep.

### Links

- [Lenovo Marketing Site](https://www.lenovo.com/us/en/p/laptops/thinkpad/thinkpadx1/thinkpad-x1-carbon-(6th-gen)/22tp2txx16g?orgRef=https%253A%252F%252Fwww.google.com%252F)
- [Support Site](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x1-carbon-6th-gen-type-20kh-20kg)
- [Drivers and Firmware](https://pcsupport.lenovo.com/us/en/products/laptops-and-netbooks/thinkpad-x-series-laptops/thinkpad-x1-carbon-6th-gen-type-20kh-20kg/downloads/ds505654)

## BIOS

The BIOS is fingerprint or password protected.

The BIOS is at version 1.59 (N23ET84W). LVFS offers 1.68 and an Intel ME update, but fwupd failed to apply them with Secure Boot off: choosing Linux-Firmware-Updater flashes the screen and returns to the boot menu. Lenovo's bootable BIOS update ISO, from the Drivers and Firmware page, updates the BIOS without fwupd.


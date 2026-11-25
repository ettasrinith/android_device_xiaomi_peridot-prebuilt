# peridot-prebuilt — prebuilt kernel & modules for Neotic OS (peridot)

Prebuilt kernel artifacts for **Xiaomi POCO F6 (peridot)** on Neotic OS **`cnb`**, consumed by
[`android_device_xiaomi_peridot`](https://github.com/ettasrinith/android_device_xiaomi_peridot).

Every Neotic Xiaomi device ships its kernel this way (`<device>-prebuilt` / `<device>-kernel` tree) —
the build never compiles a kernel from source, which avoids the CAF audio-kernel modpost failures that
come from mixing Neotic's kernel flow with LOS-style out-of-tree module builds.

## Contents

| Path | What it is |
|---|---|
| `kernel` | uncompressed ARM64 Image, kernel release `6.1.138-android14-11-g0c3d559bcd85-ab14529422` (extracted from HyperOS OS3.0.303.0.WNPINXM (India) stock boot.img via extract-files.sh) |
| `dtb/01_dtbdump_…Cliffs_SoC.dtb`, `02_dtbdump_…Cliffs_7_SoC.dtb` | individual device tree blobs (peridot's platform is **Cliffs**/SM8635; aurora's are Pineapple) — Neotic's build `cat`s `$BOARD_PREBUILT_DTBIMAGE_DIR/*.dtb` into `dtb.img`; cat of the split files is byte-identical to the original combined image |
| `dtbo.img` | DT overlay image |
| `kernel-headers/` | sanitized UAPI headers + a **stub `Makefile`** whose `headers_install` target just rsyncs the tree into `$(O)/usr/include` — this is the aurora-kernel pattern that lets vendor components do `$(shell) header queries against TARGET_KERNEL_SOURCE without a real kernel build |
| `vendor_dlkm/` | ~400 `.ko` modules + `modules.load`, `modules.blocklist` (copied to `vendor_dlkm/lib/modules`) |
| `vendor_ramdisk/` | ~308 boot-critical `.ko` + `modules.load`, `modules.load.recovery`, `modules.blocklist` |
| `system_dlkm/lib/modules/6.1.138-android14-11-g0c3d559bcd85-ab14529422/` | ~60 system-side modules, vermagic `6.1.138-android14-11-g0c3d559bcd85-ab14529422` — matches the shipped kernel exactly. QTI's `system_dlkm_modprobe.sh` iterates `/system_dlkm/lib/modules/*` and loads any dir containing `modules.load`, so the dir name is a label, not a functional key |

## Wiring in the device tree

`device/xiaomi/peridot/BoardConfig.mk` points at this tree:

```makefile
TARGET_NO_KERNEL_OVERRIDE := true
TARGET_KERNEL_SOURCE := device/xiaomi/peridot-prebuilt/kernel-headers
BOARD_PREBUILT_DTBOIMAGE / BOARD_PREBUILT_DTB(IMAGE)   # dtbo.img / dtb artifacts
BOARD_VENDOR_RAMDISK_KERNEL_MODULES / LOAD / BLOCKLIST  # wildcards over vendor_ramdisk
BOARD_VENDOR_KERNEL_MODULES / LOAD / BLOCKLIST          # wildcards over vendor_dlkm
system_dlkm modules via find-copy-subdir-files of 6.1.138-android14-11-g0c3d559bcd85-ab14529422
```

The kernel sources pinned for reference (`pure-24.0` sm8635 kernel + LOS modules/devicetrees) are
listed in the device tree's `neoteric.dependencies` — they are not built.

## Updating

Replace `kernel` + dtbo from a new build; keep `dtb/` populated with individual `*.dtb` files (never a bare `dtb.img`), refresh the three module sets
(`modules.load`/`blocklist` must match the `.ko` files present), and re-run the device build.

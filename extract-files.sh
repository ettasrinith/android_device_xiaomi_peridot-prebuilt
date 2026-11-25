#!/bin/bash
#
# Adapted from Neoteric-OS/android_device_xiaomi_aurora-kernel extract-files.sh
# (original copyright Paranoid Android, Apache-2.0).
# Extracts the HyperOS stock kernel + module sets from a fastboot firmware dump.
#

set -e

DUMP=
MY_DIR="${BASH_SOURCE%/*}"
SRC_ROOT="${MY_DIR}/../../.."
TMP_DIR=$(mktemp -d)
EXTRACT_KERNEL=true
SYSTEM_DLKM_RELEASE="6.1.138-android14-11-g0c3d559bcd85-ab14529422"
declare -a MODULE_FOLDERS=("vendor_ramdisk" "vendor_dlkm" "system_dlkm")

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-kernel )
                EXTRACT_KERNEL=false
                ;;
        * )
                DUMP="${1}"
                ;;
    esac
    shift
done

[ -f "${MY_DIR}/Module.symvers" ] || touch "${MY_DIR}/Module.symvers"
[ -f "${MY_DIR}/System.map" ] || touch "${MY_DIR}/System.map"

if [ -z "${DUMP}" ]; then
    echo "Please specify the dump!"
    exit 1
elif [ ! -d "${DUMP}" ]; then
    echo "Unable to find dump at ${DUMP}!"
    exit 1
fi

echo "Extracting files from ${DUMP}:"

### Kernel
if ${EXTRACT_KERNEL}; then
    echo "Extracting boot image.."
    ${SRC_ROOT}/system/tools/mkbootimg/unpack_bootimg.py \
        --boot_img "${DUMP}/boot.img" \
        --out "${TMP_DIR}/boot.out" > /dev/null
    cp -f "${TMP_DIR}/boot.out/kernel" "${MY_DIR}/kernel"
    echo "  - kernel ($(stat -c%s "${MY_DIR}/kernel") bytes)"
fi

### DTBs
rm -rf "${MY_DIR}/dtb"
mkdir "${MY_DIR}/dtb"

echo "Extracting vendor_boot image..."
${SRC_ROOT}/system/tools/mkbootimg/unpack_bootimg.py \
    --boot_img "${DUMP}/vendor_boot.img" \
    --out "${TMP_DIR}/vendor_boot.out" > /dev/null

if [ ! -f "${TMP_DIR}/extract_dtb.py" ]; then
    curl -sSL "https://raw.githubusercontent.com/PabloCastellano/extract-dtb/master/extract_dtb/extract_dtb.py" \
        > "${TMP_DIR}/extract_dtb.py"
fi

python3 "${TMP_DIR}/extract_dtb.py" "${TMP_DIR}/vendor_boot.out/dtb" -o "${TMP_DIR}/dtb" > /dev/null
find "${TMP_DIR}/dtb" -type f -name "*.dtb" \
    -exec cp {} "${MY_DIR}/dtb" \; \
    -exec printf "  - dtb/" \; \
    -exec basename {} \;
cp -f "${DUMP}/dtbo.img" "${MY_DIR}/dtbo.img"
echo "  - dtbo.img"

### Modules
for MODULE_FOLDER in "${MODULE_FOLDERS[@]}"; do
    rm -rf "${MY_DIR}/${MODULE_FOLDER}"
    mkdir "${MY_DIR}/${MODULE_FOLDER}"
done

for MODULE_FOLDER in "${MODULE_FOLDERS[@]}"; do
    MODULE_SRC="${DUMP}/${MODULE_FOLDER}"

    if [ "${MODULE_FOLDER}" == "vendor_ramdisk" ]; then
        lz4 -qd "${TMP_DIR}/vendor_boot.out/vendor_ramdisk00" "${TMP_DIR}/vendor_ramdisk.cpio" || true
        7z x "${TMP_DIR}/vendor_ramdisk.cpio" -o"${TMP_DIR}/vendor_ramdisk" > /dev/null
        MODULE_SRC="${TMP_DIR}/vendor_ramdisk"
    fi

    if [ "${MODULE_FOLDER}" == "system_dlkm" ]; then
        MODULE_SRC="${DUMP}/system_dlkm/flatten/lib/modules"
    fi

    if [ ! -d "${MODULE_SRC}" ]; then
        echo "Source ${MODULE_SRC} not found or empty! Skipping ${MODULE_FOLDER}."
        continue
    fi

    if [ "${MODULE_FOLDER}" == "system_dlkm" ]; then
        cp -r "${MODULE_SRC}/." "${MY_DIR}/${MODULE_FOLDER}/"
        echo "  - system_dlkm (full release dir)"
    else
        find "${MODULE_SRC}/lib/modules" -type f \
            -exec cp {} "${MY_DIR}/${MODULE_FOLDER}/" \; \
            -exec printf "  - ${MODULE_FOLDER}/" \; \
            -exec basename {} \;
    fi
done

rm -rf "${TMP_DIR}"
echo "Done."

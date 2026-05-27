# Define variables and directories
MODDIR="${0%/*}"
. $MODDIR/common_func.sh
MAGISK_VER="$(magisk -V)"

# Conditional sensitive properties

# Magisk Recovery Mode
resetprop_if_match ro.boot.mode recovery unknown
resetprop_if_match ro.bootmode recovery unknown
resetprop_if_match vendor.boot.mode recovery unknown

# SELinux
resetprop_if_diff ro.boot.selinux enforcing
# use toybox to protect stat access time reading
if [ "$(toybox cat /sys/fs/selinux/enforce)" = "0" ]; then
    chmod 640 /sys/fs/selinux/enforce
    chmod 440 /sys/fs/selinux/policy
fi

# Conditional late sensitive properties

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 1
done

# SafetyNet/Play Integrity + OEM
# avoid bootloop on some Xiaomi devices
resetprop_if_diff ro.secureboot.lockstate locked
# avoid breaking Realme fingerprint scanners
resetprop_if_diff ro.boot.flash.locked 1
resetprop_if_diff ro.boot.realme.lockstate 1
# avoid breaking Oppo fingerprint scanners
resetprop_if_diff ro.boot.vbmeta.device_state locked
# avoid breaking OnePlus display modes/fingerprint scanners
resetprop_if_diff vendor.boot.verifiedbootstate green
# avoid breaking OnePlus/Oppo fingerprint scanners on OOS/ColorOS 12+
resetprop_if_diff ro.boot.verifiedbootstate green
resetprop_if_diff ro.boot.veritymode enforcing
resetprop_if_diff vendor.boot.vbmeta.device_state locked
resetprop_if_diff persist.sys.usb.config none
resetprop_if_diff sys.usb.config none

# Other
resetprop_if_diff sys.oem_unlock_allowed 0

# -------------------------- 

# Wait for SD card to be mounted
while [ ! -d /sdcard ] || ! find /sdcard -maxdepth 0 > /dev/null 2>&1; do
    sleep 60
done

# Backup the target list if it exists and no backup is present
backup_target() {
    [ -f "$TARGET_FILE" ] && [ ! -f "$TARGET_BACKUP" ] && cat "$TARGET_FILE" > "$TARGET_BACKUP"
}
# Main function to update the target list based on various conditions
update_autolog() {
    [ -f "$MODDIR/webroot/core/target.sh" ] && sh "$MODDIR/webroot/core/target.sh"
}

# Background process to manage the target list
while true; do
        backup_target
        update_autolog
        sleep 3
        break
done

# BootHash
boothash

# Clean LSPosed Trace
monitor() {
  while true; do
    until find /data/app/*/*/oat/* -name "base.odex" -type f 2>/dev/null | grep -q .; do
      sleep 1800
    done

    find /data/app/*/*/oat/* -name "base.odex" -type f -delete 2>/dev/null
    break
  done
}

# Run in backgroud
monitor &

# Kill DroidGuard processes after a delay
killer

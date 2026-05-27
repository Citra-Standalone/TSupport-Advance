. $MODPATH/common_func.sh

# Extract version info from module properties
VERCODE=$(grep 'versionCode=' $MODPATH/module.prop | cut -d '=' -f 2)

# Get device SDK
current_sdk_version="$(getprop ro.build.version.sdk)"

# Error on < Android 8
if [ "$API" -lt 26 ]; then
    abort "! You can't use this module on Android < 8.0"
fi

# Generate Config Directory
mkdir -p $CONF

# Set command execution based on root solution
if [ "$BOOTMODE" ] && [ "$KSU" ]; then
    if command -v su &>/dev/null; then
        KSU_VERSION=$(su --version 2>/dev/null | cut -d ':' -f 1)
    fi
    echo "- Installation with KernelSU ($KSU_VERSION)"      
elif [ "$BOOTMODE" ] && [ "$APATCH" ]; then
    if [ -f "/data/adb/ap/version" ]; then
        APATCH_VERSION=$(cat /data/adb/ap/version)
    fi
    echo "- Installation with Apatch ($APATCH_VERSION)"
elif [ "$BOOTMODE" ] && [ "$MAGISK_VER_CODE" ]; then
    echo "- Installation with Magisk $MAGISK_VER($MAGISK_VER_CODE)"
    [ $MAGISK_VER_CODE -lt 27008 ]
else
    abort "! Installation from recovery not supported"
fi

[ -f "$MODPATH/webroot/core/env.sh" ] && sh "$MODPATH/webroot/core/env.sh"
[ -f "$MODPATH/webroot/core/target.sh" ] && sh "$MODPATH/webroot/core/target.sh"
[ -f "$MODPATH/webroot/core/kpm.sh" ] && sh "$MODPATH/webroot/core/kpm.sh"
[ -f "$MODPATH/webroot/core/hma.sh" ] && sh "$MODPATH/webroot/core/hma.sh"
[ -f "$MODPATH/webroot/core/suspicious_props.sh" ] && sh "$MODPATH/webroot/core/suspicious_props.sh"
[ -f "$MODPATH/webroot/core/trace_cleaner.sh" ] && sh "$MODPATH/webroot/core/trace_cleaner.sh"
[ -f "$MODPATH/webroot/core/key.sh" ] && sh "$MODPATH/webroot/core/key.sh"
boothash

sleep 1
killer

[ $OLDVERCODE -lt $VERCODE ] && echo "- Update Success" && cat $MODPATH/module.prop > /data/adb/modules/tsupport-advance/module.prop && exit 0
[ $OLDVERCODE -gt $VERCODE ] && echo "- Downgrade Success" && cat $MODPATH/module.prop > /data/adb/modules/tsupport-advance/module.prop && exit 0

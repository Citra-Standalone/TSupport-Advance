# Set module path
MODDIR="${0%/*}"
. $MODDIR/../../common_func.sh


# Define critical paths
CONF="/sdcard/TSupportConfig"
TARGET_DIR="/data/adb/tricky_store"
ROM_SIGN_PATH="/system/etc/security"

# Extract version info from module properties
VERNAME=$(grep 'version=' $MODDIR/module.prop | cut -d '=' -f 2)
VERCODE=$(grep 'versionCode=' $MODDIR/module.prop | cut -d '=' -f 2)

# Display module information
echo -e "\nBusyBox:$BUSYBOX"
echo -e "ModVer: $VERNAME($VERCODE)"
sleep 0.8

# Display system status
echo -e "\n============================"

if unzip -l $ROM_SIGN_PATH/otacerts.zip | grep -q "testkey" ; then
    echo -e "ROM Sign : testkey"
elif unzip -l $ROM_SIGN_PATH/otacerts.zip | grep -q "releasekey" ; then
    echo -e "ROM Sign : releasekey"
else
    echo -e "ROM Sign : unknown"
fi

if [ "$(getenforce)" == "Enforcing" ]; then
    echo -e "SELinux : enforcing"
elif [ "$(getenforce)" == "Permissive" ]; then
    echo -e "SELinux : permissive"
else
    echo -e "SELinux : disabled"
fi

if [ -d "$TARGET_DIR" ] && grep -q "teeBroken=true" "$TARGET_DIR/tee_status"; then
    echo -e "TEE Status : broken"
elif [ -d "$TARGET_DIR" ] && grep -q "teeBroken=false" "$TARGET_DIR/tee_status"; then
    echo -e "TEE Status : normal"
else
    echo -e "TEE Status : unknown"
fi

if cat /data/system/packages.list | awk '{print $1}' | grep -q eu.xiaomi.module.inject || getprop ro.product.mod_device | grep -q xiaomieu; then
    echo "XEU ROM : true"
    su -c pm disable eu.xiaomi.module.inject >> /dev/null
else
    echo "XEU ROM : false"
fi

if [ -d "/data/data/com.google.android.hmal" ] || [ -d "/data/data/com.tsng.hidemyapplist" ] || [ -d "/data/data/org.frknkrc44.hma_oss" ]; then
    echo "HMA'L : true"
else
    echo "HMA'L : false"
fi

echo "============================"

# Disable conflicting ROM-level props
props="persist.sys.pixelprops.pi persist.sys.pixelprops.gapps persist.sys.pixelprops.gms"
for prop in $props; do
    value=$(getprop "$prop" 2>/dev/null)
    if [ -n "$value" ]; then
        case "$value" in
            1) resetprop -n -p "$prop" 0 && echo "- Disabled ROM Spoof [$prop]" ;;
            true) resetprop -n -p "$prop" false && echo "- Disabled ROM Spoof [$prop]" ;;
        esac
    fi
done

# Disable props for specific ROMs (AOSPA, PixelOS, etc.)
props="persist.sys.pihooks.disable.gms_props persist.sys.pihooks.disable.gms_key_attestation_block"
for prop in $props; do
    value=$(getprop "$prop" 2>/dev/null)
    if [ -n "$value" ]; then
        case "$value" in
            0) resetprop -n -p "$prop" 1 && echo "- Disabled ROM Spoof [$prop]" ;;
            false) resetprop -n -p "$prop" true && echo "- Disabled ROM Spoof [$prop]" ;;
        esac
    fi
done

# Detect and handle conflicting modules
echo ""
if grep -q "es.chiteroman.bootloaderspoofer" /data/system/packages.list; then
    echo "! Conflict es.chiteroman.bootloaderspoofer"
    echo "> Removing es.chiteroman.bootloaderspoofer"
    pm uninstall --user 0 "es.chiteroman.bootloaderspoofer" > /dev/null
fi

CONFIG_XML="/data/data/com.wmods.wppenhacer/shared_prefs/com.wmods.wppenhacer_preferences.xml"
if [ ! -f "$CONFIG_XML" ]; then
    :
else
    if grep -q 'name="bootloader_spoofer" value="true"' "$CONFIG_XML"; then
        echo "! Conflict com.wmods.wppenhacer"
        echo "> Disabling BootloaderSpoofer"
        sed -i 's/\(name="bootloader_spoofer" value=\)"true"/\1"false"/' "$CONFIG_XML"
    fi
fi

if [ -f "/data/adb/zygisksu/denylist_enforce" ] && [ $(cat "/data/adb/zygisksu/denylist_enforce") == "0" ]; then
    echo "- ZygiskNext, DenyList Policy set to Unmount Only."
    echo "2" > "/data/adb/zygisksu/denylist_enforce"
fi

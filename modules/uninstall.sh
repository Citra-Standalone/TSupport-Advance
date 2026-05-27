# Define path for Tricky Store and PIF
trickystore="/data/adb/tricky_store"

# PIF Reset
if [ -f /data/system/gms_certified_props.json ]; then
	resetprop -p --delete persist.sys.spoof.gms
fi

# Cleanup and restoration logic
rm -rf /data/adb/modules/zygisk_shamiko/action.sh
rm -rf /data/adb/pif.json
rm -rf $trickystore/keybox.xml

# Restore the original keybox from backup if it exists
[ -f $trickystore/keybox.origin ] && mv $trickystore/keybox.origin $trickystore/keybox.xml

# (Optional) Restore from a different backup, or remove the backup
# cat /data/adb/tricky_store/keybox.xml.bak > /data/adb/tricky_store/keybox.xml || rm -rf /data/adb/tricky_store/keybox.xml.bak
